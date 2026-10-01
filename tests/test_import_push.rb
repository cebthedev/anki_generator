# frozen_string_literal: true

require_relative 'test_helper'
require 'zip'
require 'sqlite3'

class ImportPushCommandsTest < Minitest::Test
  include TestHelpers

  def setup
    @dir = Dir.mktmpdir('import_push_test')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def path(name)
    File.join(@dir, name)
  end

  # --- Import ---

  def test_import_markdown_builds_deck
    md = path('notes.md')
    File.write(md, "# Capitals\n\nQ: Capital of France?\nA: Paris\n")
    out = path('deck.apkg')
    ui, io = captured_ui

    AnkiGenerator::Commands::Import.new(
      deck_name: 'Geo', input_file: md, output_file: out, ui:
    ).run

    assert File.exist?(out)
    assert_match(/successfully created/, io.string)
    assert_match(/Total cards: 1/, io.string)
  end

  def test_import_with_reverse_doubles_cards
    md = path('notes.md')
    File.write(md, "Q: Q1\nA: A1\n")
    out = path('deck.apkg')

    AnkiGenerator::Commands::Import.new(
      deck_name: 'R', input_file: md, output_file: out, reverse: true, ui: silence_ui
    ).run

    # Reversed cards are emitted as their own notes (front/back swapped), so
    # the archive holds 2 notes and 2 cards.
    db = read_apkg_db(out)
    assert_equal 2, db.get_first_value('select count(*) from notes')
    assert_equal 2, db.get_first_value('select count(*) from cards')
  end

  def test_import_csv_builds_deck
    csv = path('cards.csv')
    File.write(csv, "front,back\nQ1,A1\nQ2,A2\n")
    out = path('deck.apkg')

    AnkiGenerator::Commands::Import.new(
      deck_name: 'CSV', input_file: csv, output_file: out, ui: silence_ui
    ).run

    assert File.exist?(out)
  end

  def test_import_unsupported_extension_raises
    txt = path('notes.txt')
    File.write(txt, 'hello')
    ui, = captured_ui

    assert_raises(AnkiGenerator::FileProcessingError) do
      AnkiGenerator::Commands::Import.new(
        deck_name: 'X', input_file: txt, output_file: path('x.apkg'), ui:
      ).run
    end
  end

  def test_import_missing_file_raises
    assert_raises(AnkiGenerator::FileProcessingError) do
      AnkiGenerator::Commands::Import.new(
        deck_name: 'X', input_file: path('missing.md'), output_file: path('x.apkg'), ui: silence_ui
      ).run
    end
  end

  # --- Push ---

  def test_push_command_sends_cards_to_anki_connect
    yaml = path('cards.yaml')
    File.write(yaml, [{ 'front' => 'Q1', 'back' => 'A1' }].to_yaml)

    anki_connect = Minitest::Mock.new
    anki_connect.expect(:push_deck, { added: 1, duplicate: 0 }) do |deck_name:, cards:|
      deck_name == 'Anki Deck' && cards.length == 1 && cards.first.front == 'Q1'
    end
    ui, io = captured_ui

    AnkiGenerator::Commands::Push.new(
      deck_name: 'Anki Deck', yaml_file: yaml, anki_connect:, ui:
    ).run

    anki_connect.verify
    assert_match(/Pushed 1 card/, io.string)
  end

  def test_push_empty_deck_raises
    yaml = path('empty.yaml')
    File.write(yaml, [].to_yaml)

    assert_raises(AnkiGenerator::FileProcessingError) do
      AnkiGenerator::Commands::Push.new(
        deck_name: 'Empty', yaml_file: yaml, ui: silence_ui
      ).run
    end
  end

  private

  # Extracts the sqlite db out of an .apkg and returns an open connection.
  def read_apkg_db(apkg_path)
    db_file = File.join(@dir, "extracted-#{File.basename(apkg_path)}.anki2")
    Zip::File.open(apkg_path) do |zip|
      File.binwrite(db_file, zip.find_entry('collection.anki2').get_input_stream.read)
    end
    SQLite3::Database.new(db_file)
  end
end
