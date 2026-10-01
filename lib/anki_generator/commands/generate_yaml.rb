# frozen_string_literal: true

require_relative 'prompt_based'
require_relative '../client_factory'
require_relative '../ui'

module AnkiGenerator
  module Commands
    # `anki_generator generate_yaml` — generate a YAML card file from a prompt.
    class GenerateYaml
      include PromptBased

      def initialize(prompt:, output_yaml:, model: LlmClient::DEFAULT_MODEL, difficulty: 'medium',
                     count: 10, context: nil, attach: nil, prompt_file: false,
                     client: nil, ui: UI.new)
        @prompt = prompt
        @output_yaml = output_yaml
        @difficulty = difficulty
        @count = count
        @context = context
        @attach = attach
        @prompt_file = prompt_file
        @client = client || ClientFactory.build(model:)
        @ui = ui
      end

      def run
        actual_prompt = resolve_prompt(@prompt, @prompt_file)
        attachments = resolve_attachments(@attach)

        announce(prompt: actual_prompt, difficulty: @difficulty, count: @count, attachments:)
        cards = generate_cards(
          prompt: actual_prompt, difficulty: @difficulty, count: @count,
          context: @context, attachments:
        )

        File.write(@output_yaml, yaml_document(actual_prompt, cards).to_yaml)

        @ui.success("Generated #{cards.length} flashcards!")
        @ui.info("YAML file created: #{@output_yaml}")
        preview_cards(cards)

        @ui.info('To create an Anki deck, run:')
        @ui.info("  anki_generator generate \"My Deck\" #{@output_yaml} my_deck.apkg")
      end

      private

      def yaml_document(prompt, cards)
        {
          'ai_generation' => {
            'topics' => [prompt],
            'context' => @context,
            'difficulty' => @difficulty,
            'count' => @count,
            'save_generated' => false
          },
          'cards' => cards
        }
      end
    end
  end
end
