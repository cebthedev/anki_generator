# frozen_string_literal: true

require_relative '../deck_builder'
require_relative '../client_factory'
require_relative '../ui'

module AnkiGenerator
  module Commands
    # `anki_generator generate` — build an .apkg deck from a YAML card file.
    class GenerateDeck
      def initialize(deck_name:, yaml_file:, output_file:, model: LlmClient::DEFAULT_MODEL,
                     sync_with: nil, reverse: false, jobs: 1, client: nil, ui: UI.new)
        @deck_name = deck_name
        @yaml_file = yaml_file
        @output_file = output_file
        @sync_with = sync_with
        @reverse = reverse
        @jobs = jobs
        @client = client || build_client(model)
        @ui = ui
      end

      def run
        builder = DeckBuilder.new(name: @deck_name, deck_file: @yaml_file, client: @client, jobs: @jobs, ui: @ui)
        builder.sync_with(@sync_with) if @sync_with
        builder.add_reverse_cards! if @reverse
        builder.generate_apkg(output_path: @output_file)

        @ui.success("Anki deck '#{@deck_name}' has been successfully created as #{@output_file}!")
        @ui.info("Total cards: #{builder.cards.length}")
      end

      private

      def build_client(model)
        # DeckBuilder only calls the client when the YAML has an
        # ai_generation section, so building unconditionally is safe — plain
        # card files never touch the network.
        ClientFactory.build(model:)
      end
    end
  end
end
