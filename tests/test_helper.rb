# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  enable_coverage :branch
  add_filter '/tests/'
  track_files 'lib/**/*.rb'
  minimum_coverage line: 75
end

require 'webmock/minitest'
WebMock.disable_net_connect!

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'minitest/autorun'
require 'pathname'
require 'stringio'
require 'tempfile'
require 'tmpdir'
require 'yaml'
require 'anki_generator'

module TestHelpers
  # A UI that writes to a StringIO so command output can be asserted and tests
  # stay quiet.
  def captured_ui
    io = StringIO.new
    [AnkiGenerator::UI.new(io), io]
  end

  def silence_ui
    AnkiGenerator::UI.new(StringIO.new)
  end
end
