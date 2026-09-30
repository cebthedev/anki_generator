# frozen_string_literal: true

require 'thor'
require 'dotenv/load'
require_relative 'version'
require_relative 'errors'
require_relative 'ui'
require_relative 'commands/generate_deck'
require_relative 'commands/generate_yaml'
require_relative 'commands/prompt_to_deck'
require_relative 'commands/create_ai_template'
require_relative 'commands/test_api'

module AnkiGenerator
  # Command-line interface. This class is intentionally thin: it parses
  # arguments with Thor and delegates to command objects in
  # AnkiGenerator::Commands, which hold the actual behaviour.
  class CLI < Thor
    DEFAULT_MODEL = OpenRouterClient::DEFAULT_MODEL

    def self.exit_on_failure?
      true
    end

    desc 'generate DECK_NAME YAML_FILE OUTPUT_FILE', 'Generate an Anki .apkg deck from a YAML file'
    option :api_key, type: :string, desc: 'OpenRouter API key (or set OPENROUTER_API_KEY env var)'
    option :model, type: :string, default: DEFAULT_MODEL, desc: 'AI model to use'
    option :sync_with, type: :string, desc: 'Existing YAML file to sync with'
    def generate(deck_name, yaml_file, output_file)
      run_command Commands::GenerateDeck,
                  deck_name:,
                  yaml_file:,
                  output_file:,
                  model: option_model,
                  sync_with: options[:sync_with],
                  client: build_client(required: false)
    end

    desc 'generate_yaml PROMPT OUTPUT_YAML', 'Generate a YAML file from a prompt using AI'
    option :api_key, type: :string, desc: 'OpenRouter API key (or set OPENROUTER_API_KEY env var)'
    option :model, type: :string, default: DEFAULT_MODEL, desc: 'AI model to use'
    option :difficulty, type: :string, default: 'medium', desc: 'Difficulty level (easy, medium, hard)'
    option :count, type: :numeric, default: 10, desc: 'Number of flashcards to generate'
    option :context, type: :string, desc: 'Additional context for better generation'
    option :attach, type: :array, desc: 'Attach files or directories for context'
    option :prompt_file, type: :boolean, default: false, desc: 'Treat PROMPT as a file path to read from'
    def generate_yaml(prompt, output_yaml)
      run_command Commands::GenerateYaml,
                  prompt:,
                  output_yaml:,
                  model: option_model,
                  difficulty: options[:difficulty],
                  count: options[:count],
                  context: options[:context],
                  attach: options[:attach],
                  prompt_file: options[:prompt_file],
                  client: build_client
    end

    desc 'prompt_to_deck PROMPT DECK_NAME OUTPUT_FILE', 'Generate flashcards from prompt and create deck in one step'
    option :api_key, type: :string, desc: 'OpenRouter API key (or set OPENROUTER_API_KEY env var)'
    option :model, type: :string, default: DEFAULT_MODEL, desc: 'AI model to use'
    option :difficulty, type: :string, default: 'medium', desc: 'Difficulty level (easy, medium, hard)'
    option :count, type: :numeric, default: 10, desc: 'Number of flashcards to generate'
    option :context, type: :string, desc: 'Additional context for better generation'
    option :save_yaml, type: :boolean, default: false, desc: 'Save intermediate YAML file'
    option :attach, type: :array, desc: 'Attach files or directories for context'
    option :prompt_file, type: :boolean, default: false, desc: 'Treat PROMPT as a file path to read from'
    def prompt_to_deck(prompt, deck_name, output_file)
      run_command Commands::PromptToDeck,
                  prompt:,
                  deck_name:,
                  output_file:,
                  model: option_model,
                  difficulty: options[:difficulty],
                  count: options[:count],
                  context: options[:context],
                  save_yaml: options[:save_yaml],
                  attach: options[:attach],
                  prompt_file: options[:prompt_file],
                  client: build_client
    end

    desc 'create_ai_template TEMPLATE_FILE', 'Create a template YAML file for AI generation'
    def create_ai_template(template_file)
      run_command Commands::CreateAiTemplate, template_file:
    end

    desc 'test_api', 'Test OpenRouter API connection'
    option :api_key, type: :string, desc: 'OpenRouter API key (or set OPENROUTER_API_KEY env var)'
    option :model, type: :string, default: DEFAULT_MODEL, desc: 'AI model to use'
    def test_api
      run_command Commands::TestApi, model: option_model, client: build_client
    end

    desc 'version', 'Show the gem version'
    def version
      say "anki_generator #{AnkiGenerator::VERSION}"
    end

    private

    # All AnkiGenerator errors are reported as a clean message + exit 1;
    # unexpected errors still raise with a full backtrace.
    def run_command(command_class, **args)
      command_class.new(**args, ui: UI.new).run
    rescue AnkiGenerator::Error => e
      UI.new.error("Error: #{e.message}")
      exit 1
    end

    def option_model
      options[:model] || DEFAULT_MODEL
    end

    def build_client(required: true)
      api_key = options[:api_key] || ENV.fetch('OPENROUTER_API_KEY', nil)
      return OpenRouterClient.new(api_key:, model: option_model) if api_key && !api_key.empty?
      return nil unless required

      raise ConfigurationError, 'OpenRouter API key is required (use --api_key or set OPENROUTER_API_KEY)'
    end
  end
end
