# frozen_string_literal: true

require 'date'
require 'yaml'
require_relative 'apkg_writer'
require_relative 'card'
require_relative 'errors'
require_relative 'openrouter_client'
require_relative 'ui'

module AnkiGenerator
  # Loads card definitions from YAML, optionally enriches them with AI-generated
  # cards via the OpenRouter client, and exports the result as an .apkg deck.
  class DeckBuilder
    attr_reader :name, :deck_file, :cards
    attr_accessor :client

    def initialize(name:, deck_file:, client: nil, ui: UI.new($stderr))
      @name = name
      @deck_file = deck_file
      @client = client
      @ui = ui
      @cards = []
      load_cards
    end

    def load_cards
      yaml_content = load_yaml(deck_file)

      if yaml_content.is_a?(Hash) && yaml_content['ai_generation']
        process_ai_generation(yaml_content)
      else
        @cards = build_cards(yaml_content.is_a?(Array) ? yaml_content : [])
      end
    end

    def process_ai_generation(config, attachments: nil)
      ai_config = config['ai_generation']
      existing_cards = build_cards(config['cards'] || [])

      if ai_config['topics'] && client
        ai_cards = generate_ai_cards(
          topics: ai_config['topics'],
          context: ai_config['context'],
          difficulty: ai_config['difficulty'] || 'medium',
          count: ai_config['count'] || 5,
          attachments:
        )
        @cards = existing_cards + build_cards(ai_cards)
      else
        @cards = existing_cards
      end

      return unless ai_config['save_generated'] && client

      save_generated_cards_to_yaml(config)
    end

    def generate_ai_cards(topics:, context: nil, difficulty: 'medium', count: 5, attachments: nil)
      if topics.is_a?(Array) && topics.length > 1
        client.generate_multiple_flashcards(
          topics:, context:, difficulty:, count:, attachments:
        )
      else
        topic = topics.is_a?(Array) ? topics.first : topics
        [client.generate_flashcard(topic:, context:, difficulty:, attachments:)]
      end
    end

    def save_generated_cards_to_yaml(original_config)
      output_file = deck_file.sub(/\.ya?ml\z/, '_generated.yaml')

      updated_config = original_config.dup
      updated_config['cards'] = cards.map(&:to_h)
      updated_config['ai_generation']['save_generated'] = false # Prevent recursive generation

      File.write(output_file, updated_config.to_yaml)
      @ui.info("Generated cards saved to: #{output_file}")
    end

    def generate_apkg(output_path:)
      writer = ApkgWriter.new(name:, output_path:)
      cards.each { |card| writer.add_card(card.front, card.back) }
      writer.save
    end

    def add_card(front:, back:)
      cards << Card.new(front:, back:)
    end

    # Merges cards from an existing deck YAML, deduplicating on the normalized
    # front text so re-running generation does not create duplicate cards.
    def sync_with(existing_yaml_file)
      unless File.exist?(existing_yaml_file)
        @ui.warn("Sync file not found, skipping: #{existing_yaml_file}")
        return
      end

      existing_cards = build_cards(extract_card_list(load_yaml(existing_yaml_file)))
      existing_fronts = existing_cards.map { |card| normalize(card.front) }
      new_cards = cards.reject { |card| existing_fronts.include?(normalize(card.front)) }

      @cards = existing_cards + new_cards
      @ui.info("Synced #{new_cards.length} new cards with existing deck")
    end

    private

    def load_yaml(path)
      YAML.safe_load_file(path, permitted_classes: [Time, Date], aliases: false)
    rescue Psych::Exception => e
      raise FileProcessingError, "Invalid YAML in #{path}: #{e.message}"
    rescue SystemCallError => e
      raise FileProcessingError, "Cannot read #{path}: #{e.message}"
    end

    def extract_card_list(content)
      content.is_a?(Array) ? content : content['cards'] || []
    end

    def build_cards(raw_cards)
      raw_cards.map do |raw|
        Card.new(front: raw['front'], back: raw['back'])
      rescue ValidationError => e
        @ui.warn("Skipping invalid card: #{e.message}")
        nil
      end.compact
    end

    def normalize(text)
      text.to_s.strip.downcase
    end
  end
end
