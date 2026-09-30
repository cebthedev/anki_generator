# frozen_string_literal: true

require_relative 'test_helper'
require 'anki_generator/cli'

class CliTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('cli_test')
    @yaml = File.join(@dir, 'cards.yaml')
    @apkg = File.join(@dir, 'deck.apkg')
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def capture_cli
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  def test_create_ai_template_command
    output = capture_cli { AnkiGenerator::CLI.new.create_ai_template(@yaml) }

    assert File.exist?(@yaml), 'Template file should be created'

    content = YAML.safe_load_file(@yaml)
    assert content.key?('ai_generation')
    assert content.key?('cards')
    assert_equal 'medium', content['ai_generation']['difficulty']
    assert_equal 5, content['ai_generation']['count']
    assert_match(/AI generation template created/, output)
  end

  def test_generate_command_with_traditional_yaml
    File.write(@yaml, [{ 'front' => 'Test question', 'back' => 'Test answer' }].to_yaml)

    output = capture_cli { AnkiGenerator::CLI.new.generate('Test Deck', @yaml, @apkg) }

    assert File.exist?(@apkg), 'APKG file should be created'
    assert_match(/successfully created/, output)
    assert_match(/Total cards: 1/, output)
  end

  def test_generate_command_reports_errors_cleanly
    error = capture_cli do
      assert_raises(SystemExit) do
        AnkiGenerator::CLI.new.generate('Test Deck', File.join(@dir, 'missing.yaml'), @apkg)
      end
    end

    assert_match(/Error:/, error)
    refute File.exist?(@apkg)
  end

  def test_expected_commands_are_registered
    commands = AnkiGenerator::CLI.commands.keys

    %w[generate generate_yaml prompt_to_deck create_ai_template test_api version].each do |cmd|
      assert_includes commands, cmd, "Command #{cmd} should be available"
    end
  end

  def test_generate_yaml_command_structure
    command = AnkiGenerator::CLI.commands['generate_yaml']

    assert_match(/PROMPT OUTPUT_YAML/, command.usage)
    expected_options = %i[api_key model difficulty count context attach prompt_file]
    expected_options.each { |opt| assert_includes command.options.keys, opt, "Missing #{opt}" }
  end

  def test_prompt_to_deck_command_structure
    command = AnkiGenerator::CLI.commands['prompt_to_deck']

    assert_match(/PROMPT DECK_NAME OUTPUT_FILE/, command.usage)
    expected_options = %i[api_key model difficulty count context save_yaml attach prompt_file]
    expected_options.each { |opt| assert_includes command.options.keys, opt, "Missing #{opt}" }
  end

  def test_default_options
    model_default = AnkiGenerator::CLI.commands['generate_yaml'].options[:model].default
    assert_equal AnkiGenerator::OpenRouterClient::DEFAULT_MODEL, model_default

    prompt_to_deck = AnkiGenerator::CLI.commands['prompt_to_deck']
    assert_equal 'medium', prompt_to_deck.options[:difficulty].default
    assert_equal 10, prompt_to_deck.options[:count].default
    assert_equal false, prompt_to_deck.options[:save_yaml].default
  end

  def test_attachment_and_prompt_file_option_types
    generate_yaml = AnkiGenerator::CLI.commands['generate_yaml']
    prompt_to_deck = AnkiGenerator::CLI.commands['prompt_to_deck']

    [generate_yaml, prompt_to_deck].each do |command|
      assert_equal :array, command.options[:attach].type
      assert_equal :boolean, command.options[:prompt_file].type
      assert_equal false, command.options[:prompt_file].default
    end
  end

  def test_version_command
    output = capture_cli { AnkiGenerator::CLI.new.version }
    assert_includes output, AnkiGenerator::VERSION
  end
end
