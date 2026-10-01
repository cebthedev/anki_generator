# frozen_string_literal: true

require_relative '../errors'

module AnkiGenerator
  module Importers
    # Parses study notes written in Markdown into flashcards.
    #
    # Supported card syntax:
    #   Q: What is the capital of France?
    #   A: Paris
    #
    # or, as list items:
    #   - **What is 2 + 2?** — 4
    #
    # Headings (`#`, `##`, ...) are treated as tags for the cards that follow
    # them, so a file can be organized into sections that become tag groups.
    class Markdown
      BULLET_CARD = /^\s*[-*]\s+\*\*(?<front>.+?)\*\*\s*(?:—|--|-|–|:)\s*(?<back>.+?)\s*$/
      QUESTION_LINE = /^Q:\s*(?<front>.+)$/
      ANSWER_LINE = /^A:\s*(?<back>.+)$/
      HEADING_LINE = /^#+\s+(?<title>.+?)\s*#*\s*$/

      def self.parse(text)
        new(text).parse
      end

      def initialize(text)
        @lines = text.to_s.lines.map(&:rstrip)
      end

      # Returns an array of card hashes: { 'front', 'back', 'tags' => [...] }.
      def parse
        @cards = []
        @tags = []
        @pending_question = nil

        @lines.each { |line| handle_line(line) }

        @cards
      end

      private

      def handle_line(line)
        if (match = HEADING_LINE.match(line))
          @tags = [match[:title]]
        elsif (match = QUESTION_LINE.match(line))
          @pending_question = match[:front].strip
        elsif (match = ANSWER_LINE.match(line))
          flush_answer(match[:back].strip)
        elsif (match = BULLET_CARD.match(line))
          @cards << card_hash(match[:front].strip, match[:back].strip, @tags)
        elsif !line.strip.empty?
          # Any other non-empty line cancels a dangling Q: without its A:.
          @pending_question = nil
        end
      end

      def flush_answer(back)
        return unless @pending_question

        @cards << card_hash(@pending_question, back, @tags)
        @pending_question = nil
      end

      def card_hash(front, back, tags)
        { 'front' => front, 'back' => back, 'tags' => tags.dup }
      end
    end
  end
end
