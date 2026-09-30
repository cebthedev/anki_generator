# frozen_string_literal: true

require_relative 'test_helper'

class PromptBuilderTest < Minitest::Test
  def setup
    @builder = AnkiGenerator::PromptBuilder.new
  end

  def test_single_card_prompt_includes_contract
    prompt = @builder.single_card(topic: 'Ruby basics', difficulty: 'easy', context: 'For beginners')

    assert_includes prompt, 'Ruby basics'
    assert_includes prompt, 'Difficulty level: easy'
    assert_includes prompt, 'For beginners'
    assert_includes prompt, '"front"'
    assert_includes prompt, '"back"'
  end

  def test_multiple_cards_prompt_includes_count_and_topics
    prompt = @builder.multiple_cards(topics: %w[Ruby Arrays], count: 7, difficulty: 'hard')

    assert_includes prompt, 'Create 7 flashcards'
    assert_includes prompt, 'Ruby, Arrays'
    assert_includes prompt, 'Difficulty level: hard'
  end

  def test_multiple_cards_accepts_single_topic_string
    prompt = @builder.multiple_cards(topics: 'Ruby', count: 3)
    assert_includes prompt, 'Ruby'
  end

  def test_attachments_section
    attachments = [
      { filename: 'test.rb', path: '/x', content: 'puts 1' },
      { filename: 'notes.md', path: '/y', content: '# Notes' }
    ]

    prompt = @builder.multiple_cards(topics: 'Ruby', count: 2, attachments:)

    assert_includes prompt, '=== ATTACHED FILE CONTENT ==='
    assert_includes prompt, '--- test.rb ---'
    assert_includes prompt, 'puts 1'
    assert_includes prompt, '--- notes.md ---'
    assert_includes prompt, '=== END ATTACHED CONTENT ==='
  end

  def test_no_attachments_renders_no_section
    prompt = @builder.single_card(topic: 'T')
    refute_includes prompt, 'ATTACHED FILE CONTENT'
  end

  def test_empty_attachments_renders_no_section
    prompt = @builder.single_card(topic: 'T', attachments: [])
    refute_includes prompt, 'ATTACHED FILE CONTENT'
  end
end
