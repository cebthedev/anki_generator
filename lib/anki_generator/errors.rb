# frozen_string_literal: true

module AnkiGenerator
  # Base class for all errors raised by this gem. Rescue this to catch anything
  # the library raises intentionally.
  class Error < StandardError; end

  # Raised when required configuration (e.g. API key) is missing or invalid.
  class ConfigurationError < Error; end

  # Raised when the OpenRouter API responds with an error status.
  class ApiError < Error; end

  # Raised when the API response cannot be parsed into flashcards.
  class ResponseParseError < Error; end

  # Raised when a flashcard definition is invalid (e.g. empty front/back).
  class ValidationError < Error; end

  # Raised when an input file (deck YAML, prompt file, attachment) cannot be processed.
  class FileProcessingError < Error; end
end
