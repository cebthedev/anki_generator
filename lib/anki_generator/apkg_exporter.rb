# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml'
require_relative 'card'
require_relative 'deck_builder'
require_relative 'errors'
require_relative 'ui'

module AnkiGenerator
  # Builds an .apkg deck archive from card data and returns the file bytes.
  # Extracted from the old WEBrick ExportServlet: stages a deck.yaml, runs
  # DeckBuilder, and reads back the generated archive from a temp dir.
  class ApkgExporter
    # Returns { filename:, bytes:, content_type: } for the generated archive.
    def self.export(deck_name:, cards:)
      new(deck_name:, cards:).export
    end

    def initialize(deck_name:, cards:)
      @deck_name = deck_name.to_s
      @raw_cards = cards
    end

    def export
      raise ValidationError, 'Deck name cannot be empty' if @deck_name.empty?

      cards = build_cards
      raise ValidationError, 'Add at least one card before exporting' if cards.empty?

      Dir.mktmpdir('anki_generator_serve') do |dir|
        output_path = File.join(dir, "#{@deck_name.gsub(/[^\w\- ]/, '_')}.apkg")
        builder = DeckBuilder.new(name: @deck_name, deck_file: write_deck_file(dir, cards),
                                  ui: UI.new(File::NULL))
        builder.generate_apkg(output_path:)

        {
          filename: File.basename(output_path),
          bytes: File.binread(output_path),
          content_type: 'application/octet-stream'
        }
      end
    end

    private

    def build_cards
      Array(@raw_cards).map do |raw|
        Card.new(
          front: raw['front'], back: raw['back'],
          tags: raw['tags'] || [], cloze: empty_to_nil(raw['cloze'])
        )
      end
    end

    def empty_to_nil(value)
      value.nil? || value.to_s.empty? ? nil : value
    end

    # DeckBuilder consumes a YAML path, so stage the edited cards in a temp
    # file inside the same temp dir the archive lives in.
    def write_deck_file(dir, cards)
      path = File.join(dir, 'deck.yaml')
      File.write(path, { 'cards' => cards.map(&:to_h) }.to_yaml)
      path
    end
  end
end
