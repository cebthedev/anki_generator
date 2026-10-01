# frozen_string_literal: true

require 'date'
require 'yaml'
require_relative '../errors'

module AnkiGenerator
  module Importers
    # Parses YAML card content into an array of card attribute hashes.
    #
    # Accepts either a top-level list of cards or a mapping with a 'cards' key:
    #   - front: Question
    #     back: Answer
    #     tags: [section]
    #
    # Entries missing a front or back are skipped. Invalid YAML raises
    # AnkiGenerator::ResponseParseError.
    module Yaml
      CARD_KEYS = %w[front back tags cloze].freeze

      def self.parse(content)
        parsed = YAML.safe_load(content, permitted_classes: [Time, Date], aliases: false)
        list = parsed.is_a?(Array) ? parsed : parsed['cards'] || []
        Array(list)
          .select { |raw| raw.is_a?(Hash) && raw['front'] && raw['back'] }
          .map { |raw| raw.select { |key, _| CARD_KEYS.include?(key) } }
      rescue Psych::Exception => e
        raise ResponseParseError, "Invalid YAML: #{e.message}"
      end
    end
  end
end
