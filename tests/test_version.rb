# frozen_string_literal: true

require_relative 'test_helper'

class VersionTest < Minitest::Test
  def test_version_is_semver_string
    assert_match(/\A\d+\.\d+\.\d+\z/, AnkiGenerator::VERSION)
  end

  def test_all_errors_inherit_from_base
    assert_operator AnkiGenerator::ConfigurationError, :<, AnkiGenerator::Error
    assert_operator AnkiGenerator::ApiError, :<, AnkiGenerator::Error
    assert_operator AnkiGenerator::ResponseParseError, :<, AnkiGenerator::Error
    assert_operator AnkiGenerator::ValidationError, :<, AnkiGenerator::Error
    assert_operator AnkiGenerator::FileProcessingError, :<, AnkiGenerator::Error
  end
end
