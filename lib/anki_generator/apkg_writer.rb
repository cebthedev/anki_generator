# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'securerandom'
require 'sqlite3'
require 'tmpdir'
require 'zip'
require_relative 'apkg_schema'

module AnkiGenerator
  # Builds a valid Anki 2.1 .apkg file: a zip archive containing a SQLite
  # collection database. Replaces the unmaintained `anki2` gem and gives us
  # full control over the generated schema (see ApkgSchema for the definition).
  class ApkgWriter
    CardEntry = Struct.new(:front, :back, :tags, :cloze)

    def initialize(name:, output_path:)
      @name = name
      @output_path = output_path
      @cards = []
      # Note and card ids must each be unique within their own table; simple
      # monotonic sequences starting at the current millisecond timestamp work
      # fine and keep cloze expansions collision-free.
      @note_seq = (Time.now.to_f * 1000).to_i
      @card_seq = @note_seq
    end

    # A basic card is a front/back pair; pass `cloze:` instead for an Anki
    # cloze note (a single text with {{cN::...}} deletions). One card row is
    # emitted per distinct cloze ordinal.
    def add_card(front, back, tags: [], cloze: nil)
      @cards << CardEntry.new(front.to_s, back.to_s, Array(tags).map(&:to_s), cloze&.to_s)
    end

    def save
      Dir.mktmpdir('anki_generator') do |dir|
        db_path = File.join(dir, 'collection.anki2')
        build_database(db_path)
        write_archive(db_path, File.join(dir, 'media'))
      end
      @output_path
    end

    private

    def build_database(db_path)
      SQLite3::Database.new(db_path) do |db|
        # The insert helpers below all operate on this connection, which lives
        # only for the duration of `save`; keeping it in an ivar keeps every
        # insert signature at a readable arity.
        @db = db
        db.execute_batch(ApkgSchema::SQL)
        insert_collection
        @cards.each_with_index { |card, index| insert_note(card, index) }
      end
    end

    def insert_collection
      @db.execute(
        'INSERT INTO col (id, crt, mod, scm, ver, dty, usn, ls, conf, models, decks, dconf, tags) ' \
        'VALUES (1, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?, ?, ?)',
        [now_seconds, now_millis, now_millis, ApkgSchema::SCHEMA_VERSION,
         ApkgSchema.conf_json,
         ApkgSchema.models_json(now_seconds:),
         ApkgSchema.decks_json(deck_name: @name, now_seconds:),
         ApkgSchema.dconf_json, '{}']
      )
    end

    def insert_note(card, index)
      if card.cloze && !card.cloze.empty?
        insert_cloze_note(card, index)
      else
        insert_basic_note(card, index)
      end
    end

    def insert_basic_note(card, index)
      note_id = next_note_id
      fields = "#{card.front}\x1F#{card.back}"

      insert_note_row(note_id, ApkgSchema::MODEL_ID, fields, card.front, card.tags)
      insert_card_row(next_card_id, note_id, ord: 0, due: index)
    end

    def insert_cloze_note(card, index)
      note_id = next_note_id
      ords = cloze_ords(card.cloze)

      insert_note_row(note_id, ApkgSchema::CLOZE_MODEL_ID, card.cloze, plain_text(card.cloze), card.tags)
      ords.each_with_index do |ord, offset|
        insert_card_row(next_card_id, note_id, ord:, due: index + offset)
      end
    end

    def insert_note_row(note_id, model_id, fields, sort_field, tags)
      checksum = Digest::SHA1.hexdigest(sort_field)[0, 8].to_i(16)

      @db.execute(
        'INSERT INTO notes (id, guid, mid, mod, usn, tags, flds, sfld, csum, flags, data) ' \
        'VALUES (?, ?, ?, ?, -1, ?, ?, ?, ?, 0, ?)',
        [note_id, SecureRandom.alphanumeric(10), model_id, now_seconds, tags.join(' '), fields, sort_field,
         checksum, '']
      )
    end

    def insert_card_row(card_id, note_id, ord:, due:)
      @db.execute(
        'INSERT INTO cards (id, nid, did, ord, mod, usn, type, queue, due, ivl, factor, reps, lapses, ' \
        'left, odue, odid, flags, data) VALUES (?, ?, ?, ?, ?, -1, 0, 0, ?, 0, 0, 0, 0, 0, 0, 0, 0, ?)',
        [card_id, note_id, ApkgSchema::DECK_ID, ord, now_seconds, due, '']
      )
    end

    # Distinct 1-based cloze ordinals, e.g. "{{c1::a}} {{c2::b}}" → [0, 1]
    # (card ord is zero-based; ordinal 1 → ord 0).
    def cloze_ords(cloze_text)
      cloze_text.scan(/\{\{c(\d+)::/).flatten.map(&:to_i).uniq.sort.map { |n| n - 1 }
    end

    def plain_text(cloze_text)
      cloze_text.gsub(/\{\{c\d+::(.+?)\}\}/, '\1').gsub(/\{\{.+?\}\}/, '').strip
    end

    def next_note_id
      @note_seq += 1
    end

    def next_card_id
      @card_seq += 1
    end

    def write_archive(db_path, media_path)
      File.write(media_path, '{}')
      # Re-saving over an existing .apkg must replace it, not append duplicate
      # zip entries.
      FileUtils.rm_f(@output_path)

      Zip::File.open(@output_path, Zip::File::CREATE) do |zip|
        zip.add('collection.anki2', db_path)
        zip.add('media', media_path)
      end
    end

    def now_seconds = Time.now.to_i
    def now_millis = (Time.now.to_f * 1000).to_i
  end
end
