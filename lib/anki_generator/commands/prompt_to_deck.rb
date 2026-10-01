# frozen_string_literal: true

require 'tempfile'
require_relative 'prompt_based'
require_relative '../deck_builder'
require_relative '../client_factory'
require_relative '../ui'

module AnkiGenerator
  module Commands
    # `anki_generator prompt_to_deck` — generate cards from a prompt and build
    # the .apkg deck in one step, via a temporary YAML file that is always
    # cleaned up (or persisted when --save-yaml is passed).
    class PromptToDeck
      include PromptBased

      def initialize(prompt:, deck_name:, output_file:, model: LlmClient::DEFAULT_MODEL,
                     difficulty: 'medium', count: 10, context: nil, save_yaml: false,
                     attach: nil, prompt_file: false, client: nil, ui: UI.new)
        @prompt = prompt
        @deck_name = deck_name
        @output_file = output_file
        @difficulty = difficulty
        @count = count
        @context = context
        @save_yaml = save_yaml
        @attach = attach
        @prompt_file = prompt_file
        @client = client || ClientFactory.build(model:)
        @ui = ui
      end

      def run
        actual_prompt = resolve_prompt(@prompt, @prompt_file)
        attachments = resolve_attachments(@attach)

        announce_deck(prompt: actual_prompt, difficulty: @difficulty, count: @count, attachments:)

        cards = generate_cards(
          prompt: actual_prompt, difficulty: @difficulty, count: @count,
          context: @context, attachments:
        )
        ui.success("Generated #{cards.length} flashcards!")

        export_deck(cards)

        ui.success("Anki deck '#{@deck_name}' created successfully!")
        ui.info("File: #{@output_file}")
        ui.info("Total cards: #{cards.length}")
        preview_cards(cards)
      end

      private

      def export_deck(cards)
        deck_document = build_deck_document(cards)

        Tempfile.create(['anki_generator', '.yaml']) do |file|
          file.write(deck_document.to_yaml)
          file.flush
          ui.info('Creating Anki deck...')
          DeckBuilder.new(name: @deck_name, deck_file: file.path, client:, ui:)
                     .generate_apkg(output_path: @output_file)
        end

        persist_yaml(deck_document) if @save_yaml
      end

      def persist_yaml(deck_document)
        yaml_path = @output_file.sub(/\.apkg\z/, '.yaml')
        File.write(yaml_path, deck_document.to_yaml)
        ui.info("YAML file saved: #{yaml_path}")
      end

      def build_deck_document(cards)
        # The cards are already generated at this point, so the intermediate
        # document is plain card data. Including the ai_generation section here
        # would make DeckBuilder send the prompt back through the API a second
        # time instead of using the cards we already have.
        { 'cards' => cards }
      end
    end
  end
end
