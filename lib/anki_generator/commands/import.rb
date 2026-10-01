# frozen_string_literal: true

require 'tempfile'
require_relative '../deck_builder'
require_relative '../errors'
require_relative '../importers/csv'
require_relative '../importers/markdown'
require_relative '../ui'

module AnkiGenerator
  module Commands
    # `anki_generator import` — build a deck straight from study notes
    # (Markdown or CSV) without a YAML intermediate.
    class Import
      EXTENSION_IMPORTERS = {
        '.md' => Importers::Markdown,
        '.markdown' => Importers::Markdown,
        '.csv' => Importers::Csv
      }.freeze

      def self.importer_for(path)
        EXTENSION_IMPORTERS.fetch(File.extname(path).downcase, nil)
      end

      def initialize(deck_name:, input_file:, output_file:, reverse: false, ui: UI.new)
        @deck_name = deck_name
        @input_file = input_file
        @output_file = output_file
        @reverse = reverse
        @ui = ui
      end

      def run
        cards = import_cards

        with_temp_deck(cards) do |deck_file|
          builder = DeckBuilder.new(name: @deck_name, deck_file:, ui: @ui)
          builder.add_reverse_cards! if @reverse
          builder.generate_apkg(output_path: @output_file)
          @ui.success("Anki deck '#{@deck_name}' has been successfully created as #{@output_file}!")
          @ui.info("Total cards: #{builder.cards.length}")
        end
      end

      private

      def import_cards
        importer = self.class.importer_for(@input_file)
        unless importer
          supported = EXTENSION_IMPORTERS.keys.join(', ')
          raise FileProcessingError, "Unsupported input file #{@input_file} (supported: #{supported})"
        end

        @ui.info("Importing #{@input_file}...")
        cards = importer.parse(File.read(@input_file, encoding: 'UTF-8'))
        raise FileProcessingError, "No cards found in #{@input_file}" if cards.empty?

        @ui.info("Parsed #{cards.length} card(s)")
        cards
      rescue SystemCallError => e
        raise FileProcessingError, "Cannot read #{@input_file}: #{e.message}"
      end

      # DeckBuilder loads from a YAML path, so stage the imported cards in a
      # temp file rather than duplicating export logic.
      def with_temp_deck(cards)
        Tempfile.create(['anki_generator_import', '.yaml']) do |file|
          file.write({ 'cards' => cards }.to_yaml)
          file.flush
          yield file.path
        end
      end
    end
  end
end
