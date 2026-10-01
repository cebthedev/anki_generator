# frozen_string_literal: true

require_relative 'test_helper'

class AnkiConnectClientTest < Minitest::Test
  API_URL = 'http://localhost:8765'

  def setup
    @client = AnkiGenerator::AnkiConnectClient.new
  end

  def test_deck_names
    stub_request(:post, API_URL)
      .with(body: hash_including('action' => 'deckNames'))
      .to_return(status: 200, body: { result: ['Default'], error: nil }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    assert_equal ['Default'], @client.deck_names
  end

  def test_push_deck_creates_missing_deck_and_adds_notes
    stub_request(:post, API_URL)
      .with(body: hash_including('action' => 'deckNames'))
      .to_return(status: 200, body: { result: [], error: nil }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, API_URL)
      .with(body: hash_including('action' => 'createDeck'))
      .to_return(status: 200, body: { result: nil, error: nil }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
    stub_request(:post, API_URL)
      .with(body: hash_including('action' => 'addNotes'))
      .to_return(status: 200, body: { result: [1_481_188_001, nil], error: nil }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    cards = [
      AnkiGenerator::Card.new(front: 'Q1', back: 'A1', tags: ['ruby']),
      AnkiGenerator::Card.new(front: 'Q2', back: 'A2')
    ]

    result = @client.push_deck(deck_name: 'Test', cards:)

    assert_equal({ added: 1, duplicate: 1 }, result)

    assert_requested(:post, API_URL) do |req|
      body = JSON.parse(req.body)
      params = body['params']
      body['action'] == 'addNotes' &&
        params['notes'][0]['deckName'] == 'Test' &&
        params['notes'][0]['modelName'] == 'Basic' &&
        params['notes'][0]['fields'] == { 'Front' => 'Q1', 'Back' => 'A1' } &&
        params['notes'][0]['tags'] == ['ruby']
    end
  end

  def test_ankiconnect_error_raises_typed_error
    stub_request(:post, API_URL)
      .to_return(status: 200, body: { result: nil, error: 'model was not found' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    error = assert_raises(AnkiGenerator::ApiError) { @client.deck_names }
    assert_includes error.message, 'model was not found'
  end
end
