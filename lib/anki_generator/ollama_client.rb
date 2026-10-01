# frozen_string_literal: true

require 'faraday'
require 'json'
require_relative 'errors'
require_relative 'prompt_builder'

module AnkiGenerator
  # Client for a local Ollama instance (https://ollama.com), exposing the same
  # interface as OpenRouterClient so the two are interchangeable everywhere a
  # `client` is injected. Free and offline, but needs a running Ollama server.
  class OllamaClient
    DEFAULT_URL = ENV.fetch('OLLAMA_URL', 'http://localhost:11434')
    DEFAULT_MODEL = 'llama3.2'
    DEFAULT_TIMEOUT = 300 # local models are slow; be generous
    DEFAULT_OPEN_TIMEOUT = 10

    attr_reader :model

    def initialize(model: DEFAULT_MODEL, base_url: DEFAULT_URL, timeout: DEFAULT_TIMEOUT,
                   open_timeout: DEFAULT_OPEN_TIMEOUT, prompt_builder: PromptBuilder.new)
      @model = model
      @base_url = base_url
      @timeout = timeout
      @open_timeout = open_timeout
      @prompt_builder = prompt_builder
    end

    def generate_flashcard(topic:, context: nil, difficulty: 'medium', attachments: nil)
      prompt = @prompt_builder.single_card(
        topic:, context:, difficulty:, attachments:
      )

      parse_card(chat(prompt))
    end

    def generate_multiple_flashcards(topics:, context: nil, difficulty: 'medium', count: 5, attachments: nil)
      prompt = @prompt_builder.multiple_cards(
        topics:, context:, difficulty:, count:, attachments:
      )

      parse_cards(chat(prompt))
    end

    private

    def connection
      @connection ||= Faraday.new(url: @base_url) do |conn|
        conn.request :json
        conn.response :json
        conn.adapter Faraday.default_adapter
        conn.options.timeout = @timeout
        conn.options.open_timeout = @open_timeout
      end
    end

    def chat(prompt)
      response = connection.post('api/chat') do |request|
        request.body = {
          model: @model,
          messages: [{ role: 'user', content: prompt }],
          stream: false,
          format: 'json',
          options: { temperature: 0.7 }
        }
      end

      extract_content(response)
    end

    def extract_content(response)
      raise ApiError, "Ollama error #{response.status}: #{error_body(response)}" unless response.success?

      content = response.body.dig('message', 'content')
      raise ResponseParseError, 'Ollama response missing message content' if content.nil?

      content
    end

    def error_body(response)
      body = response.body
      body.is_a?(Hash) ? body.inspect : body.to_s
    rescue StandardError
      'unparseable error body'
    end

    def parse_card(content)
      card = JSON.parse(extract_json(content))
      raise ResponseParseError, 'Expected a single flashcard object' unless card.is_a?(Hash)

      card
    rescue JSON::ParserError => e
      raise ResponseParseError, "Failed to parse Ollama response as JSON: #{e.message}"
    end

    def parse_cards(content)
      cards = JSON.parse(extract_json(content))
      cards = [cards] unless cards.is_a?(Array)

      cards
    rescue JSON::ParserError => e
      raise ResponseParseError, "Failed to parse Ollama response as JSON: #{e.message}"
    end

    # Shared with OpenRouterClient: models sometimes wrap JSON in markdown
    # fences despite instructions.
    def extract_json(content)
      stripped = content.gsub(/```(?:json)?/, '').strip
      start = stripped.index(/[\[{]/)
      finish = stripped.rindex(/[\]}]/)
      return stripped if start.nil? || finish.nil? || finish < start

      stripped[start..finish]
    end
  end
end
