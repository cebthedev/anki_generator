# frozen_string_literal: true

require_relative '../ui'

module AnkiGenerator
  module Commands
    # `anki_generator create_ai_template` — write a starter YAML file users can
    # edit and feed back into `generate`.
    class CreateAiTemplate
      TEMPLATE = {
        'ai_generation' => {
          'topics' => ['Example Topic 1', 'Example Topic 2'],
          'context' => 'Additional context for generating flashcards',
          'difficulty' => 'medium',
          'count' => 5,
          'save_generated' => true
        },
        'cards' => [
          {
            'front' => 'Example manual card front',
            'back' => 'Example manual card back'
          }
        ]
      }.freeze

      def initialize(template_file:, ui: UI.new)
        @template_file = template_file
        @ui = ui
      end

      def run
        File.write(@template_file, TEMPLATE.to_yaml)

        @ui.info("AI generation template created: #{@template_file}")
        @ui.info("Edit the file and run 'anki_generator generate' to create your deck!")
      end
    end
  end
end
