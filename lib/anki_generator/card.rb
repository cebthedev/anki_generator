# frozen_string_literal: true

require_relative 'errors'

module AnkiGenerator
  # A single flashcard. Cards are value objects: immutable and compared by content.
  #
  # Two card types are supported:
  # - basic: a front/back question-answer pair
  # - cloze: a single sentence with {{cN::hidden text}} deletions (Anki cloze)
  class Card
    CLOZE_PATTERN = /\{\{c\d+::.+?\}\}/

    attr_reader :front, :back, :tags

    def initialize(front: nil, back: nil, tags: [], cloze: nil)
      @tags = Array(tags).map { |tag| tag.to_s.strip }.reject(&:empty?)
      @cloze = cloze&.to_s&.strip

      if cloze?
        @front = @cloze
        @back = ''
        validate_cloze!
      else
        @front = front.to_s.strip
        @back = back.to_s.strip
        validate!
      end
    end

    def cloze?
      !@cloze.nil? && !@cloze.empty?
    end

    # The distinct cloze ordinals (1-based) used by this card, e.g. [1, 2].
    def cloze_indices
      @cloze.to_s.scan(/\{\{c(\d+)::/).flatten.map(&:to_i).uniq.sort
    end

    # Plain-text version of the cloze text (markers stripped) — used for the
    # note's sort field.
    def plain_text
      @cloze.to_s.gsub(/\{\{c\d+::(.+?)\}\}/, '\1').gsub(/\{\{.+?\}\}/, '').strip
    end

    def reversed
      raise ValidationError, 'Cloze cards cannot be reversed' if cloze?

      Card.new(front: back, back: front, tags:)
    end

    def to_h
      hash = { 'front' => front, 'back' => back }
      hash['tags'] = tags unless tags.empty?
      hash['cloze'] = @cloze if cloze?
      hash
    end

    def ==(other)
      other.is_a?(Card) && front == other.front && back == other.back &&
        tags == other.tags && @cloze == other.instance_variable_get(:@cloze)
    end
    alias eql? ==

    def hash
      [front, back, tags, @cloze].hash
    end

    private

    def validate!
      raise ValidationError, 'Flashcard front cannot be empty' if front.empty?
      raise ValidationError, 'Flashcard back cannot be empty' if back.empty?
    end

    def validate_cloze!
      raise ValidationError, 'Cloze text cannot be empty' if @cloze.empty?
      return if CLOZE_PATTERN.match?(@cloze)

      raise ValidationError, "Cloze text must contain at least one {{cN::...}} deletion, got: #{@cloze}"
    end
  end
end
