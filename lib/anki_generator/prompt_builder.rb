# frozen_string_literal: true

module AnkiGenerator
  # Builds the prompts sent to the LLM. Kept separate from the client so the
  # prompt contract can be tested in isolation.
  class PromptBuilder
    def single_card(topic:, context: nil, difficulty: 'medium', attachments: nil)
      <<~PROMPT.strip
        Create a single flashcard for the topic: "#{topic}"
        Difficulty level: #{difficulty}
        #{context_line(context)}
        #{attachments_section(attachments)}
        Format your response as JSON with exactly this structure:
        {
          "front": "Question or prompt",
          "back": "Answer or explanation"
        }

        Make the flashcard educational and appropriate for the #{difficulty} difficulty level.
        For the back side, provide a clear, concise explanation.
        #{attachments_hint(attachments)}
      PROMPT
    end

    def multiple_cards(topics:, context: nil, difficulty: 'medium', count: 5, attachments: nil)
      topics_list = topics.is_a?(Array) ? topics.join(', ') : topics.to_s

      <<~PROMPT.strip
        Create #{count} flashcards covering these topics: #{topics_list}
        Difficulty level: #{difficulty}
        #{context_line(context)}
        #{attachments_section(attachments)}
        Format your response as JSON with exactly this structure:
        [
          {
            "front": "Question or prompt 1",
            "back": "Answer or explanation 1"
          },
          {
            "front": "Question or prompt 2",
            "back": "Answer or explanation 2"
          }
        ]

        Make the flashcards educational, diverse, and appropriate for the #{difficulty} difficulty level.
        Ensure each flashcard covers different aspects of the topics.
        #{attachments_hint(attachments)}
      PROMPT
    end

    private

    def context_line(context)
      context ? "Additional context: #{context}" : ''
    end

    def attachments_hint(attachments)
      if attachments && !attachments.empty?
        'Use the provided file content to create more accurate and detailed flashcards.'
      else
        ''
      end
    end

    def attachments_section(attachments)
      return '' unless attachments && !attachments.empty?

      section = +"=== ATTACHED FILE CONTENT ===\n\n"
      attachments.each do |attachment|
        section << "--- #{attachment[:filename]} ---\n"
        section << "#{attachment[:content]}\n\n"
      end
      section << "=== END ATTACHED CONTENT ===\n"
      section
    end
  end
end
