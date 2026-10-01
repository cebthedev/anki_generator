# frozen_string_literal: true

require_relative 'test_helper'

class MarkdownImporterTest < Minitest::Test
  def parse(text)
    AnkiGenerator::Importers::Markdown.parse(text)
  end

  def test_qa_pairs
    cards = parse(<<~MD)
      Q: What is the capital of France?
      A: Paris

      Q: What is 2 + 2?
      A: 4
    MD

    assert_equal 2, cards.length
    assert_equal({ 'front' => 'What is the capital of France?', 'back' => 'Paris', 'tags' => [] }, cards[0])
    assert_equal '4', cards[1]['back']
  end

  def test_bullet_cards_with_bold_front
    cards = parse("- **What is Ruby?** — A programming language\n- **What is Rails?** -- A web framework\n")

    assert_equal 2, cards.length
    assert_equal 'What is Ruby?', cards[0]['front']
    assert_equal 'A programming language', cards[0]['back']
    assert_equal 'A web framework', cards[1]['back']
  end

  def test_headings_become_tags
    cards = parse(<<~MD)
      # European capitals

      ## France

      Q: Capital?
      A: Paris

      ## Spain

      Q: Capital?
      A: Madrid
    MD

    assert_equal ['France'], cards[0]['tags']
    assert_equal ['Spain'], cards[1]['tags']
  end

  def test_dangling_question_without_answer_is_dropped
    cards = parse("Q: No answer follows\n\nsome other text\n\nQ: With answer\nA: Yes\n")

    assert_equal 1, cards.length
    assert_equal 'With answer', cards[0]['front']
  end

  def test_mixed_qa_and_bullets
    cards = parse(<<~MD)
      Q: From QA syntax?
      A: Yes

      - **From bullet syntax?** — Also yes
    MD

    assert_equal 2, cards.length
  end

  def test_empty_input
    assert_empty parse('')
    assert_empty parse("# Only a heading\n\nNo cards here.\n")
  end
end
