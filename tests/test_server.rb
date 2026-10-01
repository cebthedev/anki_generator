# frozen_string_literal: true

require_relative 'test_helper'
require 'rack/test'
require 'zip'
require 'sqlite3'

class ServerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    AnkiGenerator::Server
  end

  def setup
    # rack-test defaults to Host example.org, which HostAuthorization rejects;
    # localhost is permitted by default (and matches how the CLI serves).
    header 'Host', 'localhost'
  end

  def post_json(path, payload)
    post path, payload.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  def test_index_page_serves_editor_ui
    get '/'

    assert_equal 200, last_response.status
    assert_includes last_response['Content-Type'], 'text/html'
    assert_includes last_response.body, 'Anki Generator'
    assert_includes last_response.body, 'Export .apkg'
  end

  def test_parse_markdown
    post_json '/parse', { format: 'markdown', content: "Q: Capital of France?\nA: Paris\n" }

    assert_equal 200, last_response.status
    cards = JSON.parse(last_response.body)['cards']
    assert_equal 1, cards.length
    assert_equal 'Capital of France?', cards[0]['front']
  end

  def test_parse_yaml
    post_json '/parse', { format: 'yaml', content: "- front: Q\n  back: A\n" }

    assert_equal 200, last_response.status
    assert_equal 1, JSON.parse(last_response.body)['cards'].length
  end

  def test_parse_unknown_format_returns_error
    post_json '/parse', { format: 'docx', content: 'x' }

    assert_equal 422, last_response.status
    assert_includes JSON.parse(last_response.body)['error'], 'Unknown format'
  end

  def test_parse_invalid_yaml_returns_error
    post_json '/parse', { format: 'yaml', content: "foo: [bar\n  baz: {unclosed\n" }

    assert_equal 422, last_response.status
    assert_includes JSON.parse(last_response.body)['error'], 'Invalid YAML'
  end

  def test_generate_uses_configured_provider
    fake_client = Struct.new(:model) do
      def generate_multiple_flashcards(topics:, context: nil, difficulty: 'medium', count: 5, attachments: nil) # rubocop:disable Lint/UnusedMethodArgument
        [{ 'front' => "#{topics.first}?", 'back' => "#{difficulty}/#{count}" }]
      end
    end.new('fake-model')

    built_with = nil
    factory = lambda { |**kwargs|
      built_with = kwargs
      fake_client
    }

    AnkiGenerator::ClientFactory.stub(:build, factory) do
      post_json '/generate', { prompt: 'Ruby', count: 3, difficulty: 'hard', api_key: 'k' }
    end

    assert_equal 200, last_response.status
    cards = JSON.parse(last_response.body)['cards']
    assert_equal 1, cards.length
    assert_equal 'Ruby?', cards[0]['front']
    assert_equal 'hard/3', cards[0]['back']
    # prompt/count/difficulty flow through to the client call
    assert_equal({ provider: nil, model: nil, api_key: 'k' }, built_with)
  end

  def test_export_returns_apkg_download
    post_json '/export', {
      deck_name: 'Web Deck',
      cards: [{ 'front' => 'Q1', 'back' => 'A1', 'tags' => %w[x y] },
              { 'front' => '{{c1::Paris}} is the capital', 'cloze' => '{{c1::Paris}} is the capital' }]
    }

    assert_equal 200, last_response.status
    assert_match(/attachment/, last_response['Content-Disposition'])
    assert_equal 'application/octet-stream', last_response['Content-Type']
    assert_equal 'PK', last_response.body[0, 2], 'Response should be a zip archive'

    # The archive must actually contain both notes.
    Tempfile.create(['web_export', '.apkg']) do |file|
      file.binmode
      file.write(last_response.body)
      file.flush
      Dir.mktmpdir do |dir|
        db_path = File.join(dir, 'collection.anki2')
        Zip::File.open(file.path) do |zip|
          File.binwrite(db_path, zip.find_entry('collection.anki2').get_input_stream.read)
        end
        db = SQLite3::Database.new(db_path)
        assert_equal 2, db.get_first_value('select count(*) from notes')
        assert_equal 'x y', db.get_first_value("select tags from notes where tags != ''")
        assert_operator db.get_first_value('select count(*) from cards'), :>=, 2
      end
    end
  end

  def test_export_validates_deck_name_and_cards
    post_json '/export', { deck_name: '', cards: [] }

    assert_equal 422, last_response.status
    assert_includes JSON.parse(last_response.body)['error'], 'Deck name'
  end
end
