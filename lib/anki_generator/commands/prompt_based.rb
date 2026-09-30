# frozen_string_literal: true

require_relative '../file_processor'
require_relative '../openrouter_client'
require_relative '../ui'

module AnkiGenerator
  module Commands
    # Shared behaviour for commands that turn a prompt (+ optional attachments)
    # into flashcards via the OpenRouter API.
    module PromptBased
      attr_reader :client, :ui

      def resolve_prompt(prompt, prompt_file)
        return prompt unless prompt_file

        ui.info("📄 Reading prompt from file: #{prompt}")
        FileProcessor.read_prompt_from_file(prompt)
      end

      def resolve_attachments(attach)
        return nil unless attach

        ui.info('📎 Processing attachments...')
        FileProcessor.process_attachments(attach, ui:)
      end

      def announce(prompt:, difficulty:, count:, attachments:)
        preview = truncate(prompt)
        ui.info("Generating flashcards for: #{preview}")
        announce_parameters(difficulty:, count:, attachments:)
      end

      # Deck-flavored announcement used by prompt_to_deck.
      def announce_deck(prompt:, difficulty:, count:, attachments:)
        ui.info("🚀 Generating Anki deck from prompt: #{truncate(prompt)}")
        announce_parameters(difficulty:, count:, attachments:)
        ui.info('')
      end

      def generate_cards(prompt:, difficulty:, count:, context:, attachments:)
        ui.info('Generating...')
        client.generate_multiple_flashcards(
          topics: [prompt],
          context:,
          difficulty:,
          count:,
          attachments:
        )
      end

      def truncate(text)
        text.length > 100 ? "#{text[0..100]}..." : text
      end

      def announce_parameters(difficulty:, count:, attachments:)
        ui.info("Model: #{client.model}")
        ui.info("Difficulty: #{difficulty}")
        ui.info("Count: #{count}")
        ui.info("Attachments: #{attachments&.length || 0} file(s)") if attachments
      end

      def preview_cards(cards, limit: 3)
        ui.info('')
        ui.info('Preview of generated cards:')
        cards.first(limit).each_with_index do |card, index|
          back = card['back'].length > 100 ? "#{card['back'][0..100]}..." : card['back']
          ui.info("#{index + 1}. #{card['front']}")
          ui.info("   → #{back}")
          ui.info('')
        end
      end
    end
  end
end
