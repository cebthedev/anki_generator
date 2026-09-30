# frozen_string_literal: true

require_relative 'errors'

module AnkiGenerator
  # A single flashcard. Cards are value objects: immutable and compared by content.
  class Card
    attr_reader :front, :back

    def initialize(front:, back:)
      @front = front.to_s.strip
      @back = back.to_s.strip

      validate!
    end

    def to_h
      { 'front' => front, 'back' => back }
    end

    def ==(other)
      other.is_a?(Card) && front == other.front && back == other.back
    end
    alias eql? ==

    def hash
      [front, back].hash
    end

    private

    def validate!
      raise ValidationError, 'Flashcard front cannot be empty' if front.empty?
      raise ValidationError, 'Flashcard back cannot be empty' if back.empty?
    end
  end
end
