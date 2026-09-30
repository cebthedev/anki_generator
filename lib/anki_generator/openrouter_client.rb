# frozen_string_literal: true

require 'faraday'
require 'json'
require 'dotenv/load'
require_relative 'errors'
require_relative 'prompt_builder'

module AnkiGenerator
  # Client for the OpenRouter chat completions API.
  class OpenRouterClient
    BASE_URL = 'https://openrouter.ai/api/v1'
    DEFAULT_MODEL = 'openai/gpt-4o-mini'
    DEFAULT_TIMEOUT = 120
    DEFAULT_OPEN_TIMEOUT = 10

    attr_reader :api_key, :model

    def initialize(api_key: nil, model: DEFAULT_MODEL, timeout: DEFAULT_TIMEOUT,
                   open_timeout: DEFAULT_OPEN_TIMEOUT, prompt_builder: PromptBuilder.new)
      @api_key = api_key || ENV.fetch('OPENROUTER_API_KEY', nil)
      @model = model
      @timeout = timeout
      @open_timeout = open_timeout
      @prompt_builder = prompt_builder

      return unless @api_key.nil? || @api_key.empty?

      raise ConfigurationError, 'OpenRouter API key is required (pass api_key: or set OPENROUTER_API_KEY)'
    end

    def generate_flashcard(topic:, context: nil, difficulty: 'medium', attachments: nil)
      prompt = @prompt_builder.single_card(
        topic:, context:, difficulty:, attachments:
      )

      parse_card(make_request(prompt, max_tokens: 1_000))
    end

    def generate_multiple_flashcards(topics:, context: nil, difficulty: 'medium', count: 5, attachments: nil)
      prompt = @prompt_builder.multiple_cards(
        topics:, context:, difficulty:, count:, attachments:
      )

      parse_cards(make_request(prompt, max_tokens: [count * 150, 1_000].max))
    end

    private

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |conn|
        conn.request :json
        conn.response :json
        conn.adapter Faraday.default_adapter
        conn.headers['Authorization'] = "Bearer #{@api_key}"
        conn.headers['Content-Type'] = 'application/json'
        conn.options.timeout = @timeout
        conn.options.open_timeout = @open_timeout
      end
    end

    def make_request(prompt, max_tokens:)
      # NOTE: a leading-slash path would replace the base URL's path; the
      # relative path here intentionally appends to /api/v1.
      response = connection.post('chat/completions') do |request|
        request.body = {
          model: @model,
          messages: [{ role: 'user', content: prompt }],
          temperature: 0.7,
          max_tokens:
        }
      end

      extract_content(response)
    end

    def extract_content(response)
      raise ApiError, "OpenRouter API error #{response.status}: #{error_body(response)}" unless response.success?

      content = response.body.dig('choices', 0, 'message', 'content')
      raise ResponseParseError, 'OpenRouter response missing message content' if content.nil?

      content
    end

    def error_body(response)
      body = response.body
      body.is_a?(Hash) ? (body.dig('error', 'message') || body.inspect) : body.to_s
    rescue StandardError
      'unparseable error body'
    end

    def parse_card(content)
      card = JSON.parse(extract_json(content))
      raise ResponseParseError, 'Expected a single flashcard object' unless card.is_a?(Hash)

      card
    rescue JSON::ParserError => e
      raise ResponseParseError, "Failed to parse OpenRouter response as JSON: #{e.message}"
    end

    def parse_cards(content)
      cards = JSON.parse(extract_json(content))
      cards = [cards] unless cards.is_a?(Array)

      cards
    rescue JSON::ParserError => e
      raise ResponseParseError, "Failed to parse OpenRouter response as JSON: #{e.message}"
    end

    # Models sometimes wrap JSON in markdown fences or add commentary despite
    # instructions. Strip the noise before parsing.
    def extract_json(content)
      stripped = content.gsub(/```(?:json)?/, '').strip
      start = stripped.index(/[\[{]/)
      finish = stripped.rindex(/[\]}]/)
      return stripped if start.nil? || finish.nil? || finish < start

      stripped[start..finish]
    end
  end
end
