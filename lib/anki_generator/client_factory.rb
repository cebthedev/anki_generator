# frozen_string_literal: true

require_relative 'llm_client'

module AnkiGenerator
  # Builds the unified ruby_llm-backed client. Any provider ruby_llm
  # supports (gemini, openai, anthropic, openrouter, ollama, ...) is valid;
  # pass provider: nil to auto-resolve from the model name.
  module ClientFactory
    module_function

    def build(model: nil, provider: nil, api_key: nil)
      LlmClient.new(
        model: model || ENV.fetch('ANKI_GENERATOR_MODEL', nil) || LlmClient::DEFAULT_MODEL,
        provider:,
        api_key:
      )
    end
  end
end
