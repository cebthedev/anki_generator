# frozen_string_literal: true

require_relative 'test_helper'
require 'json'
require 'sqlite3'
require 'zip'

class ApkgWriterTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('apkg_writer_test')
    @output = File.join(@dir, 'deck.apkg')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def writer(name: 'Test Deck')
    AnkiGenerator::ApkgWriter.new(name:, output_path: @output)
  end

  def extract_db
    entries = {}
    Zip::File.open(@output) do |zip|
      zip.each { |entry| entries[entry.name] = entry.get_input_stream.read }
    end
    entries
  end

  # Reads the sqlite database straight out of the zip by materializing it in a
  # temp file (SQLite3 has no in-memory restore API available in 2.x).
  def read_db
    db_file = File.join(@dir, 'extracted.anki2')
    File.binwrite(db_file, extract_db['collection.anki2'])
    SQLite3::Database.new(db_file)
  end

  def test_archive_contains_collection_and_media
    deck = writer
    deck.add_card('Question', 'Answer')
    deck.save

    entries = extract_db
    assert_includes entries.keys, 'collection.anki2'
    assert_equal '{}', entries['media']
  end

  def test_database_has_expected_schema_and_rows
    deck = writer
    deck.add_card('What is Ruby?', 'A programming language')
    deck.add_card('What is a graph?', 'Vertices and edges')
    deck.save

    db = read_db

    # decks/models/dconf are JSON *columns* of the col table, not tables.
    tables = db.execute("select name from sqlite_master where type = 'table' order by name").flatten
    assert_equal %w[cards col notes], tables

    col_columns = db.execute('PRAGMA table_info(col)').map { |row| row[1] }
    %w[conf models decks dconf tags].each do |column|
      assert_includes col_columns, column, "Missing col column #{column}"
    end

    notes = db.execute('select flds, sfld, guid, mid from notes')
    assert_equal 2, notes.length
    assert_equal "What is Ruby?\x1FA programming language", notes[0][0]
    assert_equal 'What is Ruby?', notes[0][1]
    refute_equal notes[0][2], notes[1][2], 'GUIDs must be unique'

    cards = db.execute('select nid, did, queue from cards')
    assert_equal 2, cards.length
    assert(cards.all? { |(_, did, queue)| did == 1 && queue.zero? })

    deck_json, model_json, ver = db.get_first_row('select decks, models, ver from col where id = 1')
    assert_equal 11, ver
    assert_equal 'Test Deck', JSON.parse(deck_json)['1']['name']
    assert_equal 'AnkiGenerator', JSON.parse(model_json)[AnkiGenerator::ApkgSchema::MODEL_ID.to_s]['name']
  end

  def test_checksum_matches_sha1_of_front
    deck = writer
    deck.add_card('Checksum me', 'answer')
    deck.save

    db = read_db
    csum = db.get_first_value('select csum from notes')

    assert_equal Digest::SHA1.hexdigest('Checksum me')[0, 8].to_i(16), csum
  end

  def test_card_order_maps_to_due_sequence
    deck = writer
    3.times { |i| deck.add_card("Q#{i}", "A#{i}") }
    deck.save

    db = read_db
    dues = db.execute('select due from cards order by due').flatten

    assert_equal [0, 1, 2], dues
  end

  def test_tags_are_stored_on_the_note
    deck = writer
    deck.add_card('Q', 'A', tags: %w[ruby basics])
    deck.save

    db = read_db
    assert_equal 'ruby basics', db.get_first_value('select tags from notes')
  end

  def test_cloze_note_produces_one_card_per_deletion
    deck = writer
    deck.add_card('{{c1::Paris}} is the capital of {{c2::France}}', '',
                  tags: ['geo'], cloze: '{{c1::Paris}} is the capital of {{c2::France}}')
    deck.save

    db = read_db

    notes = db.execute('select mid, flds, tags from notes')
    assert_equal 1, notes.length
    assert_equal AnkiGenerator::ApkgSchema::CLOZE_MODEL_ID, notes[0][0]
    assert_equal 'geo', notes[0][2]

    ords = db.execute('select ord from cards order by ord').flatten
    assert_equal [0, 1], ords
  end

  def test_models_column_contains_basic_and_cloze_models
    deck = writer
    deck.add_card('Q', 'A')
    deck.save

    db = read_db
    models = JSON.parse(db.get_first_value('select models from col where id = 1'))

    assert_includes models.keys, AnkiGenerator::ApkgSchema::MODEL_ID.to_s
    assert_includes models.keys, AnkiGenerator::ApkgSchema::CLOZE_MODEL_ID.to_s
  end

  def test_saving_over_an_existing_archive_replaces_it
    deck = writer
    deck.add_card('First', 'A')
    deck.save

    deck.add_card('Second', 'B')
    deck.save

    entries = extract_db
    assert_equal %w[collection.anki2 media], entries.keys.sort
    assert_equal 2, read_db.get_first_value('select count(*) from notes')
  end
end
