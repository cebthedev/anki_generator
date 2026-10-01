# frozen_string_literal: true

require 'schematist'

module AnkiGenerator
  # Schematist schemas for ruby_llm structured output. `tags` stays optional
  # because historically the model could return it and downstream card
  # handling supports it.
  class SingleCardSchema < Schematist::Schema
    string :front
    string :back
    array :tags, of: :string, required: false
  end

  # Schema for batch generation: an object wrapping a `cards` array of
  # flashcards (ruby_llm structured output requires a top-level object).
  class MultipleCardsSchema < Schematist::Schema
    array :cards do
      object do
        string :front
        string :back
        array :tags, of: :string, required: false
      end
    end
  end
end
