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
    def initialize(name:, output_path:)
      @name = name
      @output_path = output_path
      @cards = []
    end

    def add_card(front, back)
      @cards << [front.to_s, back.to_s]
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
        db.execute_batch(ApkgSchema::SQL)
        insert_collection(db)
        @cards.each_with_index { |(front, back), index| insert_note(db, front, back, index) }
      end
    end

    def insert_collection(db)
      db.execute(
        'INSERT INTO col (id, crt, mod, scm, ver, dty, usn, ls, conf, models, decks, dconf, tags) ' \
        'VALUES (1, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?, ?, ?)',
        [now_seconds, now_millis, now_millis, ApkgSchema::SCHEMA_VERSION,
         ApkgSchema.conf_json,
         ApkgSchema.models_json(now_seconds:),
         ApkgSchema.decks_json(deck_name: @name, now_seconds:),
         ApkgSchema.dconf_json, '{}']
      )
    end

    def insert_note(db, front, back, index)
      note_id = now_millis + index
      fields = "#{front}\x1F#{back}"
      checksum = Digest::SHA1.hexdigest(front)[0, 8].to_i(16)

      db.execute(
        'INSERT INTO notes (id, guid, mid, mod, usn, tags, flds, sfld, csum, flags, data) ' \
        'VALUES (?, ?, ?, ?, -1, ?, ?, ?, ?, 0, ?)',
        [note_id, SecureRandom.alphanumeric(10), ApkgSchema::MODEL_ID, now_seconds, '', fields, front, checksum, '']
      )
      db.execute(
        'INSERT INTO cards (id, nid, did, ord, mod, usn, type, queue, due, ivl, factor, reps, lapses, ' \
        'left, odue, odid, flags, data) VALUES (?, ?, ?, 0, ?, -1, 0, 0, ?, 0, 0, 0, 0, 0, 0, 0, 0, ?)',
        [note_id + 1, note_id, ApkgSchema::DECK_ID, now_seconds, index, '']
      )
    end

    def write_archive(db_path, media_path)
      File.write(media_path, '{}')

      Zip::File.open(@output_path, Zip::File::CREATE) do |zip|
        zip.add('collection.anki2', db_path)
        zip.add('media', media_path)
      end
    end

    def now_seconds = Time.now.to_i
    def now_millis = (Time.now.to_f * 1000).to_i
  end
end
