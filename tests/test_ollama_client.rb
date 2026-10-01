# frozen_string_literal: true

require_relative 'test_helper'

class OllamaClientTest < Minitest::Test
  API_URL = 'http://localhost:11434/api/chat'

  def setup
    @client = AnkiGenerator::OllamaClient.new(model: 'llama3.2')
  end

  def stub_chat(content, status: 200)
    stub_request(:post, API_URL).to_return(
      status:,
      body: { 'message' => { 'content' => content } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  def test_uses_same_interface_as_openrouter
    stub_chat('{"front": "Q", "back": "A"}')

    card = @client.generate_flashcard(topic: 'Ruby')
    assert_equal 'Q', card['front']

    assert_requested(:post, API_URL) do |req|
      body = JSON.parse(req.body)
      body['model'] == 'llama3.2' && body['stream'] == false && body['format'] == 'json'
    end
  end

  def test_multiple_cards
    stub_chat('[{"front": "Q1", "back": "A1"}, {"front": "Q2", "back": "A2"}]')

    cards = @client.generate_multiple_flashcards(topics: %w[a b], count: 2)

    assert_equal 2, cards.length
  end

  def test_api_error_raises_typed_error
    stub_chat('', status: 404)

    assert_raises(AnkiGenerator::ApiError) do
      @client.generate_flashcard(topic: 'x')
    end
  end

  def test_invalid_json_raises_parse_error
    stub_chat('not json')

    assert_raises(AnkiGenerator::ResponseParseError) do
      @client.generate_flashcard(topic: 'x')
    end
  end

  def test_no_api_key_required
    # Ollama is local; initialization must never raise for a missing key.
    assert_equal 'llama3.2', AnkiGenerator::OllamaClient.new.model
  end
end

class ClientFactoryTest < Minitest::Test
  def test_builds_openrouter_client
    client = AnkiGenerator::ClientFactory.build(provider: 'openrouter', api_key: 'k')
    assert_instance_of AnkiGenerator::OpenRouterClient, client
  end

  def test_builds_ollama_client
    client = AnkiGenerator::ClientFactory.build(provider: 'ollama')
    assert_instance_of AnkiGenerator::OllamaClient, client
  end

  def test_unknown_provider_raises_typed_error
    assert_raises(AnkiGenerator::ConfigurationError) do
      AnkiGenerator::ClientFactory.build(provider: 'skynet')
    end
  end
end
