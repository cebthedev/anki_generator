# frozen_string_literal: true

require_relative '../anki_connect_client'
require_relative '../deck_builder'
require_relative '../ui'

module AnkiGenerator
  module Commands
    # `anki_generator push` — send a YAML card file straight into a running
    # Anki via the AnkiConnect add-on, skipping the .apkg import step.
    class Push
      def initialize(deck_name:, yaml_file:, url: AnkiConnectClient::DEFAULT_URL,
                     anki_connect: nil, ui: UI.new)
        @deck_name = deck_name
        @yaml_file = yaml_file
        @anki_connect = anki_connect || AnkiConnectClient.new(base_url: url)
        @ui = ui
      end

      def run
        builder = DeckBuilder.new(name: @deck_name, deck_file: @yaml_file, ui: @ui)
        raise FileProcessingError, "No cards found in #{@yaml_file}" if builder.cards.empty?

        @ui.info("Pushing #{builder.cards.length} card(s) to deck '#{@deck_name}' via AnkiConnect...")
        result = @anki_connect.push_deck(deck_name: @deck_name, cards: builder.cards)

        @ui.success("Pushed #{result[:added]} card(s) to Anki!")
        @ui.info("Skipped #{result[:duplicate]} duplicate(s)") if result[:duplicate].positive?
      end
    end
  end
end
