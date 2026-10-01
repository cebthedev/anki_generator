# frozen_string_literal: true

require 'csv'
require_relative '../errors'

module AnkiGenerator
  module Importers
    # Parses a CSV file into flashcards.
    #
    # Expected columns: front,back — with an optional third column of tags.
    # A header row (front,back[,tags]) is detected case-insensitively and
    # skipped. Tags are separated by `|` within the third column.
    class Csv
      TAG_SEPARATOR = '|'

      def self.parse(text)
        new(text).parse
      end

      def initialize(text)
        @text = text.to_s
      end

      # Returns an array of card hashes: { 'front', 'back', 'tags' => [...] }.
      def parse
        rows = CSV.parse(@text)
        rows = rows[1..] if header_row?(rows.first)

        rows.filter_map do |row|
          front, back, tags = row
          next nil if front.to_s.strip.empty?

          {
            'front' => front.to_s.strip,
            'back' => back.to_s.strip,
            'tags' => tags.to_s.split(TAG_SEPARATOR).map(&:strip).reject(&:empty?)
          }
        end
      rescue CSV::MalformedCSVError => e
        raise FileProcessingError, "Invalid CSV: #{e.message}"
      end

      private

      def header_row?(row)
        return false unless row

        row[0].to_s.strip.casecmp('front').zero?
      end
    end
  end
end
