# frozen_string_literal: true

require_relative 'test_helper'

class CardTest < Minitest::Test
  def test_value_object_semantics
    a = AnkiGenerator::Card.new(front: 'Q', back: 'A')
    b = AnkiGenerator::Card.new(front: 'Q', back: 'A')

    assert_equal a, b
    assert_equal a.hash, b.hash
    refute_equal a, AnkiGenerator::Card.new(front: 'Q', back: 'B')
  end

  def test_strips_whitespace
    card = AnkiGenerator::Card.new(front: "  Q\n", back: ' A  ')
    assert_equal 'Q', card.front
    assert_equal 'A', card.back
  end

  def test_to_h
    card = AnkiGenerator::Card.new(front: 'Q', back: 'A')
    assert_equal({ 'front' => 'Q', 'back' => 'A' }, card.to_h)
  end

  def test_rejects_empty_fields
    assert_raises(AnkiGenerator::ValidationError) { AnkiGenerator::Card.new(front: '', back: 'A') }
    assert_raises(AnkiGenerator::ValidationError) { AnkiGenerator::Card.new(front: 'Q', back: '') }
  end

  def test_tags_are_normalized
    card = AnkiGenerator::Card.new(front: 'Q', back: 'A', tags: [' ruby ', '', :basics])
    assert_equal %w[ruby basics], card.tags
    assert_equal %w[ruby basics], card.to_h['tags']
  end

  def test_card_equality_includes_tags
    refute_equal AnkiGenerator::Card.new(front: 'Q', back: 'A', tags: ['x']),
                 AnkiGenerator::Card.new(front: 'Q', back: 'A', tags: ['y'])
  end

  def test_cloze_card
    card = AnkiGenerator::Card.new(cloze: '{{c1::Paris}} is the capital of {{c2::France}}')

    assert card.cloze?
    assert_equal [1, 2], card.cloze_indices
    assert_equal 'Paris is the capital of France', card.plain_text
    assert_equal '{{c1::Paris}} is the capital of {{c2::France}}', card.front
    assert_equal({ 'front' => card.front, 'back' => '', 'cloze' => card.front }, card.to_h)
  end

  def test_cloze_requires_a_deletion_marker
    assert_raises(AnkiGenerator::ValidationError) { AnkiGenerator::Card.new(cloze: 'Just text') }
    assert_raises(AnkiGenerator::ValidationError) { AnkiGenerator::Card.new(cloze: '') }
  end

  def test_reversed_card_swaps_fields_and_keeps_tags
    card = AnkiGenerator::Card.new(front: 'Q', back: 'A', tags: ['x'])
    reversed = card.reversed

    assert_equal 'A', reversed.front
    assert_equal 'Q', reversed.back
    assert_equal %w[x], reversed.tags
  end

  def test_cloze_card_cannot_be_reversed
    card = AnkiGenerator::Card.new(cloze: '{{c1::x}} is y')
    assert_raises(AnkiGenerator::ValidationError) { card.reversed }
  end
end
