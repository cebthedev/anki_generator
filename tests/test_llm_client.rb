# frozen_string_literal: true

require_relative 'test_helper'

class LlmClientTest < Minitest::Test
  API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent'

  def setup
    RubyLLM.configure { |c| c.gemini_api_key = 'test_key' }
  end

  def stub_completion(content, status: 200)
    stub_request(:post, API_URL).to_return(
      status:,
      body: {
        'candidates' => [{ 'content' => { 'role' => 'model', 'parts' => [{ 'text' => content }] } }],
        'usageMetadata' => { 'promptTokenCount' => 1, 'candidatesTokenCount' => 1 }
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def test_initialization_defaults
    client = AnkiGenerator::LlmClient.new

    assert_equal AnkiGenerator::LlmClient::DEFAULT_MODEL, client.model
    assert_equal 'gemini-3.8-flash', client.model
  end

  def test_initialization_with_custom_model
    client = AnkiGenerator::LlmClient.new(model: 'gpt-5')

    assert_equal 'gpt-5', client.model
  end

  def test_api_key_without_provider_raises_configuration_error
    error = assert_raises(AnkiGenerator::ConfigurationError) do
      AnkiGenerator::LlmClient.new(api_key: 'test_key')
    end
    assert_includes error.message, 'provider'
  end

  def test_api_key_with_provider_configures_ruby_llm
    AnkiGenerator::LlmClient.new(provider: 'openai', api_key: 'explicit_openai_key')

    assert_equal 'explicit_openai_key', RubyLLM.config.openai_api_key
  end

  def test_google_api_key_configures_gemini_when_gemini_key_unset
    with_env('GOOGLE_API_KEY', 'google_fallback_key') do
      without_env('GEMINI_API_KEY') do
        RubyLLM.configure { |c| c.gemini_api_key = nil }

        AnkiGenerator::LlmClient.new

        assert_equal 'google_fallback_key', RubyLLM.config.gemini_api_key
      end
    end
  ensure
    RubyLLM.configure { |c| c.gemini_api_key = 'test_key' }
  end

  def test_generate_flashcard_success
    stub_completion('{"front": "What is Ruby?", "back": "A programming language"}')

    card = client.generate_flashcard(topic: 'Ruby programming')

    assert_equal 'What is Ruby?', card['front']
    assert_equal 'A programming language', card['back']
  end

  def test_generate_flashcard_includes_optional_tags
    stub_completion('{"front": "Q", "back": "A", "tags": ["ruby"]}')

    card = client.generate_flashcard(topic: 'Anything')

    assert_equal ['ruby'], card['tags']
  end

  def test_generate_multiple_flashcards_success
    stub_completion('{"cards": [{"front": "Q1", "back": "A1"}, {"front": "Q2", "back": "A2"}]}')

    cards = client.generate_multiple_flashcards(topics: %w[Ruby Rails], count: 2)

    assert_equal 2, cards.length
    assert_equal 'Q1', cards[0]['front']
    assert_equal 'Q2', cards[1]['front']
  end

  def test_api_error_raises_typed_error
    stub_request(:post, API_URL).to_return(
      status: 401,
      body: { 'error' => { 'message' => 'invalid key', 'code' => 401 } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    error = assert_raises(AnkiGenerator::ApiError) do
      client.generate_flashcard(topic: 'Test topic')
    end
    assert_includes error.message, 'invalid key'
  end

  def test_non_conforming_response_raises_parse_error
    stub_completion('not json at all')

    assert_raises(AnkiGenerator::ResponseParseError) do
      client.generate_flashcard(topic: 'Test topic')
    end
  end

  def test_response_without_cards_array_raises_parse_error
    stub_completion('{"front": "Q", "back": "A"}')

    assert_raises(AnkiGenerator::ResponseParseError) do
      client.generate_multiple_flashcards(topics: ['Ruby'], count: 1)
    end
  end

  def test_request_includes_prompt_and_schema
    stub_completion('{"front": "Q", "back": "A"}')

    client.generate_flashcard(topic: 'Ruby metaprogramming', difficulty: 'hard', context: 'For seniors')

    assert_requested(:post, API_URL) do |req|
      body = JSON.parse(req.body)
      text = body['contents'].first['parts'].first['text']
      schema = body.dig('generationConfig', 'responseJsonSchema')
      text.include?('Ruby metaprogramming') &&
        text.include?('For seniors') &&
        schema['properties'].key?('front') &&
        schema['properties'].key?('back')
    end
  end

  def test_factory_builds_client_with_default_model
    client = AnkiGenerator::ClientFactory.build

    assert_instance_of AnkiGenerator::LlmClient, client
    assert_equal AnkiGenerator::LlmClient::DEFAULT_MODEL, client.model
  end

  def test_factory_builds_client_with_explicit_provider_and_key
    client = AnkiGenerator::ClientFactory.build(provider: 'openai', api_key: 'factory_key', model: 'gpt-5')

    assert_instance_of AnkiGenerator::LlmClient, client
    assert_equal 'gpt-5', client.model
    assert_equal 'factory_key', RubyLLM.config.openai_api_key
  end

  def test_factory_honors_anki_generator_model_env_var
    original = ENV.fetch('ANKI_GENERATOR_MODEL', nil)
    ENV['ANKI_GENERATOR_MODEL'] = 'gemini-3.8-flash-custom'

    client = AnkiGenerator::ClientFactory.build
    assert_equal 'gemini-3.8-flash-custom', client.model
  ensure
    original ? ENV['ANKI_GENERATOR_MODEL'] = original : ENV.delete('ANKI_GENERATOR_MODEL')
  end

  private

  def client
    AnkiGenerator::LlmClient.new
  end

  def without_env(name)
    saved = ENV.delete(name)
    yield
  ensure
    ENV[name] = saved if saved
  end

  def with_env(name, value)
    saved = ENV.fetch(name, nil)
    ENV[name] = value
    yield
  ensure
    saved ? ENV[name] = saved : ENV.delete(name)
  end
end
