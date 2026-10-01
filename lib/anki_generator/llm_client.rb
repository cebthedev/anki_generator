# frozen_string_literal: true

require 'json'
require 'dotenv/load'
require 'ruby_llm'
require_relative 'errors'
require_relative 'prompt_builder'
require_relative 'card_schema'

module AnkiGenerator
  # Provider-agnostic LLM client backed by the ruby_llm gem. Any provider
  # ruby_llm supports (gemini, openai, anthropic, openrouter, ollama, ...)
  # can be used by passing `provider:`; when omitted, the provider is
  # resolved from the model name. Standard provider env vars
  # (GEMINI_API_KEY, OPENAI_API_KEY, ANTHROPIC_API_KEY, OPENROUTER_API_KEY)
  # are picked up automatically, with GOOGLE_API_KEY accepted as the
  # Google-official alias for the gemini key; pass `api_key:` to override
  # explicitly (which requires an explicit `provider:`).
  #
  # Card generation uses ruby_llm's structured output (Schematist schemas),
  # so responses come back as parsed JSON instead of prompt-honoured text.
  class LlmClient
    DEFAULT_MODEL = 'gemini-3.8-flash'
    TEMPERATURE = 0.7

    # Standard env vars mapped to the ruby_llm configuration options they
    # feed. Provider slugs not listed here (e.g. ollama) need no key.
    ENV_KEY_VARS = %w[GEMINI_API_KEY OPENAI_API_KEY ANTHROPIC_API_KEY OPENROUTER_API_KEY].freeze

    attr_reader :model

    def initialize(model: DEFAULT_MODEL, provider: nil, api_key: nil, prompt_builder: PromptBuilder.new)
      @model = model
      @provider = provider&.to_s
      @prompt_builder = prompt_builder

      configure_api_key(api_key)
      configure_ollama_base
    end

    def generate_flashcard(topic:, context: nil, difficulty: 'medium', attachments: nil)
      prompt = @prompt_builder.single_card(
        topic:, context:, difficulty:, attachments:
      )

      response = make_request(prompt, max_tokens: 1_000, schema: SingleCardSchema)
      parsed = schema_parsed(response)
      raise ResponseParseError, 'Expected a single flashcard object' unless parsed.is_a?(Hash)

      parsed
    end

    def generate_multiple_flashcards(topics:, context: nil, difficulty: 'medium', count: 5, attachments: nil)
      prompt = @prompt_builder.multiple_cards(
        topics:, context:, difficulty:, count:, attachments:
      )

      response = make_request(prompt, max_tokens: [count * 150, 1_000].max, schema: MultipleCardsSchema)
      parsed = schema_parsed(response)
      cards = parsed['cards'] if parsed.is_a?(Hash)
      raise ResponseParseError, 'Expected a "cards" array in the LLM response' unless cards.is_a?(Array)

      cards
    end

    private

    def configure_api_key(api_key)
      if api_key && !api_key.empty?
        unless @provider
          raise ConfigurationError,
                'api_key requires an explicit provider (pass provider:, e.g. "gemini", "openai", "openrouter")'
        end

        return RubyLLM.configure { |c| c.public_send("#{@provider}_api_key=", api_key) }
      end

      pairs = env_api_key_pairs
      return if pairs.empty?

      RubyLLM.configure do |c|
        pairs.each do |env_name, option_name|
          c.public_send("#{option_name}=", ENV.fetch(env_name, nil)) if c.public_send(option_name).to_s.empty?
        end
      end
    end

    # [env var, ruby_llm option] pairs for every configured key, filtered to
    # the requested provider when one was given. GOOGLE_API_KEY (Google's
    # official convention) feeds the gemini key when GEMINI_API_KEY is unset.
    def env_api_key_pairs
      pairs = ENV_KEY_VARS.map { |name| [name, name.downcase] }
      if present?(ENV.fetch('GOOGLE_API_KEY', nil)) && !present?(ENV.fetch('GEMINI_API_KEY', nil))
        pairs << %w[GOOGLE_API_KEY gemini_api_key]
      end

      if @provider
        allowed = ["#{@provider.upcase}_API_KEY"]
        allowed << 'GOOGLE_API_KEY' if @provider == 'gemini'
        pairs.select! { |name, _| allowed.include?(name) }
      end

      pairs.select { |name, _| present?(ENV.fetch(name, nil)) }
    end

    def present?(value)
      !value.nil? && !value.empty?
    end

    # Continuity with the old OllamaClient: OLLAMA_URL points the ollama
    # provider at a custom server.
    def configure_ollama_base
      ollama_url = ENV.fetch('OLLAMA_URL', nil)
      return if ollama_url.nil? || ollama_url.empty?

      RubyLLM.configure { |c| c.ollama_api_base = ollama_url }
    end

    # A fresh chat per request: DeckBuilder calls the client from multiple
    # worker threads, and RubyLLM::Chat is not safe to share across threads.
    def make_request(prompt, max_tokens:, schema:)
      RubyLLM.chat(model: @model, provider: @provider&.to_sym)
             .with_temperature(TEMPERATURE)
             .with_max_output_tokens(max_tokens)
             .with_schema(schema)
             .ask(prompt)
    rescue RubyLLM::ConfigurationError => e
      raise ConfigurationError, e.message
    rescue RubyLLM::Error, RubyLLM::ModelNotFoundError => e
      raise ApiError, e.message
    end

    # ruby_llm parses the response content as JSON (Message#parsed); nil or
    # invalid JSON means the model did not honour the schema.
    def schema_parsed(response)
      response.parsed || raise(ResponseParseError, 'LLM response was empty')
    rescue JSON::ParserError => e
      raise ResponseParseError, "Failed to parse LLM response as JSON: #{e.message}"
    end
  end
end
