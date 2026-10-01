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
  # cards via an LLM client, and exports the result as an .apkg deck.
  class DeckBuilder
    attr_reader :name, :deck_file, :cards
    attr_accessor :client

    def initialize(name:, deck_file:, client: nil, jobs: 1, ui: UI.new($stderr))
      @name = name
      @deck_file = deck_file
      @client = client
      @jobs = jobs
      @ui = ui
      @cards = []
      load_cards
    end

    def load_cards
      yaml_content = load_yaml(deck_file)

      if yaml_content.is_a?(Hash) && yaml_content['ai_generation']
        process_ai_generation(yaml_content)
      else
        @cards = build_cards(extract_card_list(yaml_content))
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
          attachments:,
          jobs: ai_config['jobs'] || @jobs
        )
        @cards = existing_cards + build_cards(ai_cards)
      else
        @cards = existing_cards
      end

      return unless ai_config['save_generated'] && client

      save_generated_cards_to_yaml(config)
    end

    # Generates AI cards for the given topics. With jobs > 1 and multiple
    # topics, each topic is requested in parallel (one API call per topic,
    # count cards each); with jobs == 1 all topics go in a single batched
    # request, which is cheaper but may produce less focused cards.
    def generate_ai_cards(topics:, context: nil, difficulty: 'medium', count: 5, attachments: nil, jobs: 1)
      topic_list = Array(topics)

      if topic_list.length > 1 && jobs > 1
        generate_topics_in_parallel(topic_list, context:, difficulty:, count:, attachments:, jobs:)
      elsif topic_list.length > 1
        client.generate_multiple_flashcards(
          topics: topic_list, context:, difficulty:, count:, attachments:
        )
      else
        [client.generate_flashcard(topic: topic_list.first, context:, difficulty:, attachments:)]
      end
    end

    # Appends a reversed copy of every basic card (back becomes front) — the
    # classic "recognition + recall" pattern. Cloze cards are skipped.
    def add_reverse_cards!
      originals = cards.dup
      originals.reject(&:cloze?).each { |card| cards << card.reversed }
      @ui.info("Added #{cards.length - originals.length} reversed cards")
      cards
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
      cards.each do |card|
        if card.cloze?
          writer.add_card(card.front, card.back, tags: card.tags, cloze: card.front)
        else
          writer.add_card(card.front, card.back, tags: card.tags)
        end
      end
      writer.save
    end

    def add_card(front:, back:, tags: [], cloze: nil)
      cards << Card.new(front:, back:, tags:, cloze:)
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

    def generate_topics_in_parallel(topics, context:, difficulty:, count:, attachments:, jobs:)
      work = topics.dup
      lock = Mutex.new
      results = Queue.new

      threads = [jobs, topics.length].min.times.map do
        Thread.new do
          loop do
            topic = lock.synchronize { work.pop }
            break if topic.nil?

            client.generate_multiple_flashcards(
              topics: [topic], context:, difficulty:, count:, attachments:
            ).each { |card| results << card }
          end
        end
      end
      threads.each(&:join)

      collected = []
      collected << results.pop until results.empty?
      collected
    end

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
      Array(raw_cards).map do |raw|
        next nil unless raw.is_a?(Hash)

        Card.new(front: raw['front'], back: raw['back'], tags: raw['tags'] || [], cloze: raw['cloze'])
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
