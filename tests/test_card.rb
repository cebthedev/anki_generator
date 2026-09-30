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
end
