# frozen_string_literal: true

require_relative 'test_helper'
require 'anki_generator/cli'
require 'net/http'
require 'zip'
require 'sqlite3'

class ServerTest < Minitest::Test
  def setup
    # The in-process WEBrick server is real localhost HTTP; allow it while
    # keeping all external network access stubbed.
    WebMock.allow_net_connect!(allow_localhost: true)
    @server, @port, @thread =
      AnkiGenerator::Commands::Serve.start_background(ui: AnkiGenerator::UI.new(File::NULL))
  end

  def teardown
    @server.shutdown
    @thread.join(5)
    WebMock.disable_net_connect!
  end

  def get(path)
    Net::HTTP.get_response(URI("http://127.0.0.1:#{@port}#{path}"))
  end

  def post(path, payload)
    uri = URI("http://127.0.0.1:#{@port}#{path}")
    Net::HTTP.post(uri, payload.to_json, 'Content-Type' => 'application/json')
  end

  def test_index_page_serves_editor_ui
    response = get('/')

    assert_equal '200', response.code
    assert_includes response['Content-Type'], 'text/html'
    assert_includes response.body, 'Anki Generator'
    assert_includes response.body, 'Export .apkg'
  end

  def test_parse_markdown
    response = post('/parse', { format: 'markdown', content: "Q: Capital of France?\nA: Paris\n" })

    assert_equal '200', response.code
    cards = JSON.parse(response.body)['cards']
    assert_equal 1, cards.length
    assert_equal 'Capital of France?', cards[0]['front']
  end

  def test_parse_yaml
    response = post('/parse', { format: 'yaml', content: "- front: Q\n  back: A\n" })

    assert_equal '200', response.code
    assert_equal 1, JSON.parse(response.body)['cards'].length
  end

  def test_parse_unknown_format_returns_error
    response = post('/parse', { format: 'docx', content: 'x' })

    assert_equal '422', response.code
    assert_includes JSON.parse(response.body)['error'], 'Unknown format'
  end

  def test_generate_uses_configured_provider
    stub_request(:post, 'https://openrouter.ai/api/v1/chat/completions')
      .to_return(status: 200,
                 body: { choices: [{ message: { content: '[{"front": "Q", "back": "A"}]' } }] }.to_json,
                 headers: { 'Content-Type' => 'application/json' })

    response = post('/generate', { prompt: 'Ruby', count: 1, api_key: 'k' })

    assert_equal '200', response.code
    assert_equal 1, JSON.parse(response.body)['cards'].length
  end

  def test_export_returns_apkg_download
    response = post('/export', {
                      deck_name: 'Web Deck',
                      cards: [{ 'front' => 'Q1', 'back' => 'A1', 'tags' => %w[x y] },
                              { 'front' => '{{c1::Paris}} is the capital', 'cloze' => '{{c1::Paris}} is the capital' }]
                    })

    assert_equal '200', response.code
    assert_match(/attachment/, response['Content-Disposition'])
    assert_equal 'PK', response.body[0, 2], 'Response should be a zip archive'

    # The archive must actually contain both notes.
    Tempfile.create(['web_export', '.apkg']) do |file|
      file.binmode
      file.write(response.body)
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
    response = post('/export', { deck_name: '', cards: [] })

    assert_equal '422', response.code
    assert_includes JSON.parse(response.body)['error'], 'Deck name'
  end
end
