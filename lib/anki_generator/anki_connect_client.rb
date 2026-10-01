# frozen_string_literal: true

require 'faraday'
require 'json'
require_relative 'card'
require_relative 'errors'

module AnkiGenerator
  # Talks to AnkiConnect (https://foosoft.net/projects/anki-connect), the
  # add-on that exposes a local HTTP API inside a running Anki. Pushes cards
  # straight into a deck — no .apkg import step.
  class AnkiConnectClient
    DEFAULT_URL = 'http://localhost:8765'
    MODEL_NAME = 'Basic'

    attr_reader :base_url

    def initialize(base_url: DEFAULT_URL)
      @base_url = base_url
    end

    # Creates the deck if needed and adds the cards. Returns
    # { added:, duplicate: } counts. Raises ApiError when Anki is unreachable
    # or AnkiConnect reports a failure.
    def push_deck(deck_name:, cards:)
      ensure_deck(deck_name)

      payload = Array(cards).map do |card|
        {
          deckName: deck_name,
          modelName: MODEL_NAME,
          fields: { Front: card.front, Back: card.back },
          tags: card.tags,
          options: { allowDuplicate: false }
        }
      end

      response = invoke('addNotes', notes: payload)
      { added: response.compact.length, duplicate: response.count(nil) }
    end

    def deck_names
      invoke('deckNames')
    end

    def create_deck(name)
      invoke('createDeck', deck: name)
    end

    # AnkiConnect answers every action with {result, error}.
    def invoke(action, **params)
      response = connection.post do |request|
        request.body = { action:, version: 6, params: }.to_json
      end

      unless response.success?
        raise ApiError,
              "AnkiConnect error #{response.status}: #{response.body} (is Anki running with AnkiConnect?)"
      end

      body = response.body
      raise ApiError, "AnkiConnect error: #{body['error']}" if body.is_a?(Hash) && body['error']

      body.is_a?(Hash) ? body['result'] : body
    rescue Faraday::ConnectionFailed => e
      raise ApiError, "Cannot reach AnkiConnect at #{@base_url}: #{e.message}"
    end

    private

    def ensure_deck(deck_name)
      create_deck(deck_name) unless deck_names.include?(deck_name)
    end

    def connection
      @connection ||= Faraday.new(url: @base_url) do |conn|
        conn.request :json
        conn.response :json
        conn.adapter Faraday.default_adapter
        conn.options.open_timeout = 5
        conn.options.timeout = 60
      end
    end
  end
end
