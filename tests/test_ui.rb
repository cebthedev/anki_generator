# frozen_string_literal: true

require_relative 'test_helper'

class UiTest < Minitest::Test
  def test_prefixes_messages
    io = StringIO.new
    ui = AnkiGenerator::UI.new(io)

    ui.info('plain')
    ui.success('done')
    ui.warn('careful')
    ui.error('broken')

    output = io.string
    assert_includes output, "plain\n"
    assert_includes output, "✅ done\n"
    assert_includes output, "⚠️  careful\n"
    assert_includes output, "❌ broken\n"
  end

  def test_defaults_to_stdout
    assert_equal $stdout, AnkiGenerator::UI.new.instance_variable_get(:@io)
  end
end
