# frozen_string_literal: true

require_relative 'test_helper'

class OpenRouterClientTest < Minitest::Test
  API_URL = 'https://openrouter.ai/api/v1/chat/completions'

  def setup
    @api_key = 'test_api_key'
    @client = AnkiGenerator::OpenRouterClient.new(api_key: @api_key)
  end

  def stub_completion(content, status: 200)
    stub_request(:post, API_URL).to_return(
      status:,
      body: { 'choices' => [{ 'message' => { 'content' => content } }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def test_initialization_with_api_key
    client = AnkiGenerator::OpenRouterClient.new(api_key: 'test_key')
    assert_equal 'test_key', client.api_key
    assert_equal AnkiGenerator::OpenRouterClient::DEFAULT_MODEL, client.model
  end

  def test_initialization_with_custom_model
    client = AnkiGenerator::OpenRouterClient.new(api_key: 'test_key', model: 'anthropic/claude-sonnet-4')
    assert_equal 'anthropic/claude-sonnet-4', client.model
  end

  def test_initialization_without_api_key_raises_typed_error
    without_env_key do
      assert_raises(AnkiGenerator::ConfigurationError) { AnkiGenerator::OpenRouterClient.new }
    end
  end

  def test_initialization_with_env_var
    with_env_key('env_api_key') do
      client = AnkiGenerator::OpenRouterClient.new
      assert_equal 'env_api_key', client.api_key
    end
  end

  def test_connection_has_timeouts
    connection = @client.send(:connection)
    assert_equal 120, connection.options.timeout
    assert_equal 10, connection.options.open_timeout
  end

  def test_generate_flashcard_success
    stub_completion('{"front": "What is Ruby?", "back": "A programming language"}')

    card = @client.generate_flashcard(topic: 'Ruby programming')

    assert_equal 'What is Ruby?', card['front']
    assert_equal 'A programming language', card['back']
  end

  def test_generate_flashcard_strips_markdown_fences
    stub_completion("```json\n{\"front\": \"Q\", \"back\": \"A\"}\n```")

    card = @client.generate_flashcard(topic: 'Anything')

    assert_equal 'Q', card['front']
    assert_equal 'A', card['back']
  end

  def test_generate_multiple_flashcards_success
    stub_completion('[{"front": "Q1", "back": "A1"}, {"front": "Q2", "back": "A2"}]')

    cards = @client.generate_multiple_flashcards(topics: %w[Ruby Rails], count: 2)

    assert_equal 2, cards.length
    assert_equal 'Q1', cards[0]['front']
    assert_equal 'Q2', cards[1]['front']
  end

  def test_generate_multiple_wraps_single_object_response
    stub_completion('{"front": "Q", "back": "A"}')

    cards = @client.generate_multiple_flashcards(topics: 'Ruby', count: 1)

    assert_equal 1, cards.length
    assert_equal 'Q', cards[0]['front']
  end

  def test_api_error_raises_typed_error_with_status
    stub_request(:post, API_URL).to_return(
      status: 401,
      body: { 'error' => { 'message' => 'invalid key' } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    error = assert_raises(AnkiGenerator::ApiError) do
      @client.generate_flashcard(topic: 'Test topic')
    end
    assert_includes error.message, '401'
    assert_includes error.message, 'invalid key'
  end

  def test_invalid_json_raises_parse_error
    stub_completion('Invalid JSON response')

    assert_raises(AnkiGenerator::ResponseParseError) do
      @client.generate_flashcard(topic: 'Test topic')
    end
  end

  def test_missing_content_raises_parse_error
    stub_request(:post, API_URL).to_return(
      status: 200,
      body: { 'choices' => [{ 'message' => {} }] }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    assert_raises(AnkiGenerator::ResponseParseError) do
      @client.generate_flashcard(topic: 'Test topic')
    end
  end

  def test_request_includes_prompt_and_model
    stub_completion('{"front": "Q", "back": "A"}')

    @client.generate_flashcard(topic: 'Ruby metaprogramming', difficulty: 'hard', context: 'For seniors')

    assert_requested(:post, API_URL) do |req|
      body = JSON.parse(req.body)
      body['model'] == AnkiGenerator::OpenRouterClient::DEFAULT_MODEL &&
        body['messages'].first['content'].include?('Ruby metaprogramming') &&
        body['messages'].first['content'].include?('For seniors')
    end
  end

  def test_attachments_are_included_in_request
    stub_completion('{"front": "Q", "back": "A"}')

    attachments = [{ filename: 'app.rb', path: '/x', content: 'class App; end' }]
    @client.generate_flashcard(topic: 'This code', attachments:)

    assert_requested(:post, API_URL) do |req|
      JSON.parse(req.body)['messages'].first['content'].include?('class App; end')
    end
  end

  private

  def without_env_key
    saved = ENV.delete('OPENROUTER_API_KEY')
    yield
  ensure
    ENV['OPENROUTER_API_KEY'] = saved if saved
  end

  def with_env_key(value)
    saved = ENV.fetch('OPENROUTER_API_KEY', nil)
    ENV['OPENROUTER_API_KEY'] = value
    yield
  ensure
    saved ? ENV['OPENROUTER_API_KEY'] = saved : ENV.delete('OPENROUTER_API_KEY')
  end
end
