# frozen_string_literal: true

require_relative '../deck_builder'
require_relative '../openrouter_client'
require_relative '../ui'

module AnkiGenerator
  module Commands
    # `anki_generator generate` — build an .apkg deck from a YAML card file.
    class GenerateDeck
      def initialize(deck_name:, yaml_file:, output_file:, model: OpenRouterClient::DEFAULT_MODEL,
                     sync_with: nil, client: nil, ui: UI.new)
        @deck_name = deck_name
        @yaml_file = yaml_file
        @output_file = output_file
        @sync_with = sync_with
        @client = client || build_client(model)
        @ui = ui
      end

      def run
        builder = DeckBuilder.new(name: @deck_name, deck_file: @yaml_file, client: @client, ui: @ui)
        builder.sync_with(@sync_with) if @sync_with
        builder.generate_apkg(output_path: @output_file)

        @ui.success("Anki deck '#{@deck_name}' has been successfully created as #{@output_file}!")
        @ui.info("Total cards: #{builder.cards.length}")
      end

      private

      def build_client(model)
        return nil if (ENV['OPENROUTER_API_KEY'] || '').empty?

        OpenRouterClient.new(model:)
      end
    end
  end
end
