# frozen_string_literal: true

require_relative 'test_helper'

class CsvImporterTest < Minitest::Test
  def parse(text)
    AnkiGenerator::Importers::Csv.parse(text)
  end

  def test_with_header_row
    cards = parse("front,back\nWhat is Ruby?,A language\nWhat is Rails?,A framework\n")

    assert_equal 2, cards.length
    assert_equal({ 'front' => 'What is Ruby?', 'back' => 'A language', 'tags' => [] }, cards[0])
  end

  def test_without_header_row
    cards = parse('Q1,A1')

    assert_equal 1, cards.length
    assert_equal 'Q1', cards[0]['front']
  end

  def test_tags_column_with_pipe_separator
    cards = parse("front,back,tags\nQ,A,ruby | basics\n")

    assert_equal %w[ruby basics], cards[0]['tags']
  end

  def test_skips_empty_front_rows
    cards = parse("front,back\n,A with no question\nQ,A\n")

    assert_equal 1, cards.length
  end

  def test_malformed_csv_raises_typed_error
    assert_raises(AnkiGenerator::FileProcessingError) { parse("front,back\n\"unclosed quote") }
  end
end
