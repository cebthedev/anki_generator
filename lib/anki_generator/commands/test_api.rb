# frozen_string_literal: true

require_relative '../openrouter_client'
require_relative '../ui'

module AnkiGenerator
  module Commands
    # `anki_generator test_api` — verify the OpenRouter API connection by
    # generating a single sample card.
    class TestApi
      def initialize(model: OpenRouterClient::DEFAULT_MODEL, client: nil, ui: UI.new)
        @client = client || OpenRouterClient.new(model:)
        @ui = ui
      end

      def run
        ui.info('Testing OpenRouter API connection...')
        ui.info("Model: #{client.model}")

        card = client.generate_flashcard(topic: 'Ruby programming', difficulty: 'easy')

        ui.success('API connection successful!')
        ui.info('Sample generated card:')
        ui.info("Front: #{card['front']}")
        ui.info("Back: #{card['back']}")
      end

      private

      attr_reader :client, :ui
    end
  end
end
