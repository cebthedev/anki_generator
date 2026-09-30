# frozen_string_literal: true

require_relative 'test_helper'
require 'anki_generator/cli'

class CommandsTest < Minitest::Test
  include TestHelpers

  def setup
    @dir = Dir.mktmpdir('commands_test')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def path(name)
    File.join(@dir, name)
  end

  def stub_client(cards: nil, single: nil)
    Class.new do
      attr_reader :model

      define_method(:initialize) { @model = 'stub-model' }
      define_method(:generate_multiple_flashcards) { |**_kwargs| cards }
      define_method(:generate_flashcard) { |**_kwargs| single }
    end.new
  end

  def test_generate_yaml_writes_document_and_previews
    client = stub_client(cards: [{ 'front' => 'Q1', 'back' => 'A1' }])
    ui, io = captured_ui
    output = path('cards.yaml')

    AnkiGenerator::Commands::GenerateYaml.new(
      prompt: 'Ruby basics', output_yaml: output, count: 1, client:, ui:
    ).run

    document = YAML.safe_load_file(output)
    assert_equal ['Ruby basics'], document['ai_generation']['topics']
    assert_equal 1, document['ai_generation']['count']
    assert_equal [{ 'front' => 'Q1', 'back' => 'A1' }], document['cards']

    assert_match(/Generated 1 flashcards!/, io.string)
    assert_match(/1\. Q1/, io.string)
  end

  def test_generate_yaml_reads_prompt_from_file
    client = stub_client(cards: [{ 'front' => 'Q', 'back' => 'A' }])
    prompt_file = path('prompt.txt')
    File.write(prompt_file, "Study these notes\n")
    output = path('out.yaml')

    AnkiGenerator::Commands::GenerateYaml.new(
      prompt: prompt_file, output_yaml: output, prompt_file: true, client:, ui: silence_ui
    ).run

    assert_equal ['Study these notes'], YAML.safe_load_file(output)['ai_generation']['topics']
  end

  def test_prompt_to_deck_creates_deck_and_cleans_up_tempfiles
    client = stub_client(cards: [{ 'front' => 'Q1', 'back' => 'A1' }, { 'front' => 'Q2', 'back' => 'A2' }])
    ui, io = captured_ui
    output = path('deck.apkg')

    AnkiGenerator::Commands::PromptToDeck.new(
      prompt: 'Ruby basics', deck_name: 'My Deck', output_file: output, client:, ui:
    ).run

    assert File.exist?(output), 'Deck should be created'
    assert_match(/Anki deck 'My Deck' created successfully!/, io.string)
    assert_match(/Total cards: 2/, io.string)

    # The old implementation wrote temp_#{timestamp}.yaml into the working
    # directory; the command must never leak intermediate files.
    assert Dir.glob('temp_*.yaml').empty?, 'No temp YAML should leak into the working directory'
    leftovers = Dir.glob(File.join(Dir.tmpdir, 'anki_generator*.yaml'))
    assert leftovers.empty?, "Tempfile should be cleaned up, found: #{leftovers}"
  end

  def test_prompt_to_deck_save_yaml_persists_document
    client = stub_client(cards: [{ 'front' => 'Q', 'back' => 'A' }])
    output = path('saved.apkg')

    AnkiGenerator::Commands::PromptToDeck.new(
      prompt: 'Topic', deck_name: 'D', output_file: output, save_yaml: true,
      client:, ui: silence_ui
    ).run

    yaml_path = path('saved.yaml')
    assert File.exist?(yaml_path), 'YAML should be persisted next to the deck'
    assert_equal [{ 'front' => 'Q', 'back' => 'A' }], YAML.safe_load_file(yaml_path)['cards']
  end

  def test_test_api_reports_sample_card
    client = stub_client(single: { 'front' => 'FQ', 'back' => 'BA' })
    ui, io = captured_ui

    AnkiGenerator::Commands::TestApi.new(client:, ui:).run

    assert_match(/API connection successful!/, io.string)
    assert_match(/Front: FQ/, io.string)
  end

  def test_generate_deck_command_with_sync
    main = path('main.yaml')
    sync = path('sync.yaml')
    File.write(main, [{ 'front' => 'Q1', 'back' => 'A1' }].to_yaml)
    File.write(sync, [{ 'front' => 'Q2', 'back' => 'A2' }].to_yaml)
    output = path('merged.apkg')
    ui, io = captured_ui

    AnkiGenerator::Commands::GenerateDeck.new(
      deck_name: 'Merged', yaml_file: main, output_file: output, sync_with: sync, ui:
    ).run

    assert File.exist?(output)
    assert_match(/Synced 1 new cards/, io.string)
    assert_match(/Total cards: 2/, io.string)
  end
end
