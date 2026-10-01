# frozen_string_literal: true

require_relative 'ollama_client'
require_relative 'openrouter_client'

module AnkiGenerator
  # Builds an LLM client for the requested provider. Both clients expose the
  # same interface (generate_flashcard / generate_multiple_flashcards), so
  # callers never need to know which provider is in use.
  module ClientFactory
    PROVIDERS = %w[openrouter ollama].freeze

    module_function

    # Raises ConfigurationError for unknown providers.
    def build(provider:, model: nil, api_key: nil, structured: false)
      case provider.to_s
      when 'openrouter'
        OpenRouterClient.new(
          api_key:, model: model || OpenRouterClient::DEFAULT_MODEL, structured:
        )
      when 'ollama'
        OllamaClient.new(model: model || OllamaClient::DEFAULT_MODEL)
      else
        raise ConfigurationError, "Unknown provider '#{provider}' (available: #{PROVIDERS.join(', ')})"
      end
    end
  end
end
