# frozen_string_literal: true

require_relative 'test_helper'

class DeckBuilderTest < Minitest::Test
  include TestHelpers

  def setup
    @dir = Dir.mktmpdir('deck_builder_test')
    @deck_yaml = path_for('flashcards.yaml')
    @ai_yaml = path_for('ai_flashcards.yaml')
    @sync_yaml = path_for('sync_flashcards.yaml')

    @flashcards = [
      { 'front' => 'What is Big O notation?',
        'back' => 'A notation describing the limiting behavior of a function.' },
      { 'front' => 'Define a graph.', 'back' => 'Vertices connected by edges.' }
    ]
    File.write(@deck_yaml, @flashcards.to_yaml)

    @ai_config = {
      'ai_generation' => {
        'topics' => ['Ruby programming', 'Data structures'],
        'context' => 'Computer science fundamentals',
        'difficulty' => 'medium',
        'count' => 2,
        'save_generated' => false
      },
      'cards' => [{ 'front' => 'Manual card', 'back' => 'Manual answer' }]
    }
    File.write(@ai_yaml, @ai_config.to_yaml)

    File.write(@sync_yaml, [{ 'front' => 'Existing card', 'back' => 'Existing answer' }].to_yaml)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def builder_for(file, **opts)
    AnkiGenerator::DeckBuilder.new(name: 'test', deck_file: file, ui: silence_ui, **opts)
  end

  def path_for(name)
    File.join(@dir, name)
  end

  def test_loads_traditional_format
    builder = builder_for(@deck_yaml)
    assert_equal 2, builder.cards.length
    assert_equal 'What is Big O notation?', builder.cards.first.front
  end

  def test_loads_ai_format_without_client_as_manual_only
    builder = builder_for(@ai_yaml)
    assert_equal 1, builder.cards.length
    assert_equal 'Manual card', builder.cards.first.front
  end

  def test_skips_invalid_cards_with_warning
    file = path_for('invalid.yaml')
    File.write(file, [{ 'front' => '', 'back' => 'x' }, { 'front' => 'ok', 'back' => 'fine' }].to_yaml)

    builder = builder_for(file)
    assert_equal 1, builder.cards.length
  end

  def test_rejects_yaml_aliases
    file = path_for('alias.yaml')
    File.write(file, "base: &base\n  front: q\n  back: a\ndupe:\n  <<: *base\n")

    assert_raises(AnkiGenerator::FileProcessingError) { builder_for(file) }
  end

  def test_raises_for_missing_deck_file
    assert_raises(AnkiGenerator::FileProcessingError) { builder_for(path_for('nope.yaml')) }
  end

  def test_generate_apkg_creates_file
    output = path_for('out.apkg')
    builder_for(@deck_yaml).generate_apkg(output_path: output)
    assert File.exist?(output), 'The .apkg file should be created'
  end

  def test_add_card
    builder = builder_for(@deck_yaml)
    builder.add_card(front: 'New question', back: 'New answer')

    assert_equal 3, builder.cards.length
    assert_equal 'New question', builder.cards.last.front
  end

  def test_add_card_rejects_empty_front
    builder = builder_for(@deck_yaml)
    assert_raises(AnkiGenerator::ValidationError) { builder.add_card(front: '', back: 'answer') }
  end

  def test_process_ai_generation_with_stub_client
    builder = builder_for(@ai_yaml)
    builder.client = stub_multiple_client
    builder.process_ai_generation(@ai_config)

    assert_equal 3, builder.cards.length
    assert_equal 'Manual card', builder.cards[0].front
    assert_equal 'What is Ruby?', builder.cards[1].front
    assert_equal 'What is an array?', builder.cards[2].front
  end

  def test_process_ai_generation_with_attachments
    builder = builder_for(@ai_yaml)
    builder.client = stub_attachment_client
    attachments = [{ filename: 'test.rb', path: '/path/to/test.rb', content: 'puts 1' }]

    builder.process_ai_generation(@ai_config, attachments:)

    assert_equal 4, builder.cards.length
    assert_equal 'What file was attached?', builder.cards[3].front
    assert_equal 'File: test.rb', builder.cards[3].back
  end

  def test_process_ai_generation_passes_attachments_through
    client = stub_multiple_client
    builder = builder_for(@ai_yaml)
    builder.client = client
    attachments = [{ filename: 'test.txt', content: 'test content' }]

    builder.process_ai_generation(@ai_config, attachments:)

    assert_equal attachments, client.last_attachments
  end

  def test_generate_ai_cards_single_topic
    builder = builder_for(@deck_yaml, client: stub_single_client)
    result = builder.generate_ai_cards(topics: 'Ruby programming')

    assert_equal 1, result.length
    assert_equal 'What is Ruby?', result[0]['front']
  end

  def test_generate_ai_cards_multiple_topics
    builder = builder_for(@deck_yaml, client: stub_multiple_client)
    result = builder.generate_ai_cards(topics: %w[Ruby Arrays])

    assert_equal 2, result.length
    assert_equal 'What is an array?', result[1]['front']
  end

  def test_generate_ai_cards_single_topic_with_attachments
    builder = builder_for(@deck_yaml, client: stub_attachment_aware_single_client)
    attachments = [{ filename: 'example.rb', path: '/x', content: 'class Example; end' }]

    result = builder.generate_ai_cards(topics: 'Ruby programming', attachments:)

    assert_equal "What's in example.rb?", result[0]['front']
  end

  def test_save_generated_cards_to_yaml
    file = path_for('save_ai.yaml')
    File.write(file,
               @ai_config.merge('ai_generation' => @ai_config['ai_generation'].merge('save_generated' => true)).to_yaml)

    builder = builder_for(file)
    builder.client = stub_multiple_client
    builder.process_ai_generation(YAML.safe_load_file(file))

    generated = path_for('save_ai_generated.yaml')
    assert File.exist?(generated), 'Generated cards should be written to a _generated.yaml file'

    content = YAML.safe_load_file(generated)
    assert_equal 3, content['cards'].length
    assert_equal false, content['ai_generation']['save_generated']
  end

  def test_sync_merges_without_duplicates
    duplicate = path_for('dup.yaml')
    File.write(duplicate, (@flashcards + [{ 'front' => 'Existing card', 'back' => 'Different answer' }]).to_yaml)

    builder = builder_for(duplicate)
    builder.sync_with(@sync_yaml)

    assert_equal 3, builder.cards.length
    existing = builder.cards.find { |card| card.front == 'Existing card' }
    assert_equal 'Existing answer', existing.back
  end

  def test_sync_is_case_insensitive_and_trims
    duplicate = path_for('dup_case.yaml')
    File.write(duplicate, [{ 'front' => '  existing CARD ', 'back' => 'new' }].to_yaml)

    builder = builder_for(duplicate)
    builder.sync_with(@sync_yaml)

    assert_equal 1, builder.cards.length
  end

  def test_sync_with_missing_file_warns_and_keeps_cards
    builder = builder_for(@deck_yaml)
    builder.sync_with(path_for('missing.yaml'))

    assert_equal 2, builder.cards.length
  end

  # --- Reverse cards ---

  def test_add_reverse_cards_doubles_basic_cards
    builder = builder_for(@deck_yaml)
    builder.add_reverse_cards!

    assert_equal 4, builder.cards.length
    reversed = builder.cards.last
    assert_equal 'Vertices connected by edges.', reversed.front
    assert_equal 'Define a graph.', reversed.back
  end

  def test_add_reverse_cards_skips_cloze
    file = path_for('cloze.yaml')
    File.write(file,
               [{ 'front' => 'Q', 'back' => 'A' },
                { 'cloze' => '{{c1::Ruby}} is a language' }].to_yaml)

    builder = builder_for(file)
    builder.add_reverse_cards!

    assert_equal 3, builder.cards.length
    assert_equal 1, builder.cards.count(&:cloze?)
  end

  # --- Parallel generation ---

  def test_generate_ai_cards_parallel_covers_all_topics
    client = parallel_spy_client
    builder = builder_for(@deck_yaml, client:)

    result = builder.generate_ai_cards(topics: %w[T1 T2 T3 T4 T5], jobs: 3)

    assert_equal %w[T1 T2 T3 T4 T5].sort, client.seen_topics.sort
    assert_equal 5, client.calls.length, 'one API call per topic, spread across workers'
    assert(client.calls.all? { |call_topics| call_topics.length == 1 })
    assert_equal 5, result.length
  end

  def test_generate_ai_cards_jobs_one_uses_single_batched_request
    client = parallel_spy_client
    builder = builder_for(@deck_yaml, client:)

    builder.generate_ai_cards(topics: %w[T1 T2], jobs: 1)

    assert_equal 1, client.calls.length, 'jobs: 1 must use one batched call'
    assert_equal %w[T1 T2], client.calls.first
  end

  # --- Cards with tags and cloze from YAML ---

  def test_loads_cards_with_tags_and_cloze
    file = path_for('rich.yaml')
    File.write(file,
               [{ 'front' => 'Q', 'back' => 'A', 'tags' => %w[x y] },
                { 'cloze' => '{{c1::Paris}} is the capital' }].to_yaml)

    builder = builder_for(file)

    assert_equal %w[x y], builder.cards.first.tags
    assert builder.cards.last.cloze?
  end

  private

  # Spy client that records each call's topics (mutex-guarded, so it is safe to
  # call from worker threads) and returns one card per requested topic.
  def parallel_spy_client
    Class.new do
      attr_reader :calls

      def initialize
        @calls = []
        @lock = Mutex.new
      end

      def seen_topics
        @calls.flatten
      end

      def generate_multiple_flashcards(**kwargs)
        topics = Array(kwargs[:topics])
        @lock.synchronize { @calls << topics }
        topics.map { |topic| { 'front' => "Card about #{topic}", 'back' => 'A' } }
      end
    end.new
  end

  def stub_single_client
    Class.new do
      def generate_flashcard(**)
        { 'front' => 'What is Ruby?', 'back' => 'A programming language' }
      end
    end.new
  end

  def stub_multiple_client
    Class.new do
      attr_reader :last_attachments

      def generate_multiple_flashcards(**kwargs)
        @last_attachments = kwargs[:attachments]
        [
          { 'front' => 'What is Ruby?', 'back' => 'A programming language' },
          { 'front' => 'What is an array?', 'back' => 'A data structure' }
        ]
      end
    end.new
  end

  def stub_attachment_client
    Class.new do
      def generate_multiple_flashcards(**kwargs)
        cards = [
          { 'front' => 'What is Ruby?', 'back' => 'A programming language' },
          { 'front' => 'What is an array?', 'back' => 'A data structure' }
        ]
        attachments = kwargs[:attachments]
        if attachments && !attachments.empty?
          cards << { 'front' => 'What file was attached?', 'back' => "File: #{attachments.first[:filename]}" }
        end
        cards
      end
    end.new
  end

  def stub_attachment_aware_single_client
    Class.new do
      def generate_flashcard(**kwargs)
        attachments = kwargs[:attachments]
        if attachments && !attachments.empty?
          { 'front' => "What's in #{attachments.first[:filename]}?", 'back' => 'Code content' }
        else
          { 'front' => 'What is Ruby?', 'back' => 'A programming language' }
        end
      end
    end.new
  end
end
