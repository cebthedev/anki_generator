# frozen_string_literal: true

require 'thor'
require 'dotenv/load'
require_relative 'version'
require_relative 'errors'
require_relative 'ui'
require_relative 'client_factory'
require_relative 'commands/create_ai_template'
require_relative 'commands/generate_deck'
require_relative 'commands/generate_yaml'
require_relative 'commands/import'
require_relative 'commands/prompt_to_deck'
require_relative 'commands/push'
require_relative 'commands/serve'
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

    class_option :provider,
                 type: :string, default: 'openrouter', enum: ClientFactory::PROVIDERS,
                 desc: 'LLM provider (openrouter or ollama)'

    desc 'generate DECK_NAME YAML_FILE OUTPUT_FILE', 'Generate an Anki .apkg deck from a YAML file'
    option :api_key, type: :string, desc: 'OpenRouter API key (or set OPENROUTER_API_KEY env var)'
    option :model, type: :string, desc: 'AI model to use (provider default if omitted)'
    option :sync_with, type: :string, desc: 'Existing YAML file to sync with'
    option :reverse, type: :boolean, default: false, desc: 'Add reversed copy of each basic card'
    option :structured, type: :boolean, default: false, desc: 'Ask the model for strict JSON output'
    option :jobs, type: :numeric, default: 1, desc: 'Parallel API calls for multi-topic generation'
    def generate(deck_name, yaml_file, output_file)
      run_command Commands::GenerateDeck,
                  deck_name:,
                  yaml_file:,
                  output_file:,
                  model: option_model,
                  sync_with: options[:sync_with],
                  reverse: options[:reverse],
                  jobs: options[:jobs],
                  client: build_client(required: false)
    end

    desc 'generate_yaml PROMPT OUTPUT_YAML', 'Generate a YAML file from a prompt using AI'
    option :api_key, type: :string, desc: 'OpenRouter API key (or set OPENROUTER_API_KEY env var)'
    option :model, type: :string, desc: 'AI model to use (provider default if omitted)'
    option :difficulty, type: :string, default: 'medium', desc: 'Difficulty level (easy, medium, hard)'
    option :count, type: :numeric, default: 10, desc: 'Number of flashcards to generate'
    option :context, type: :string, desc: 'Additional context for better generation'
    option :attach, type: :array, desc: 'Attach files or directories for context'
    option :prompt_file, type: :boolean, default: false, desc: 'Treat PROMPT as a file path to read from'
    option :structured, type: :boolean, default: false, desc: 'Ask the model for strict JSON output'
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
    option :model, type: :string, desc: 'AI model to use (provider default if omitted)'
    option :difficulty, type: :string, default: 'medium', desc: 'Difficulty level (easy, medium, hard)'
    option :count, type: :numeric, default: 10, desc: 'Number of flashcards to generate'
    option :context, type: :string, desc: 'Additional context for better generation'
    option :save_yaml, type: :boolean, default: false, desc: 'Save intermediate YAML file'
    option :attach, type: :array, desc: 'Attach files or directories for context'
    option :prompt_file, type: :boolean, default: false, desc: 'Treat PROMPT as a file path to read from'
    option :structured, type: :boolean, default: false, desc: 'Ask the model for strict JSON output'
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

    desc 'import DECK_NAME INPUT_FILE OUTPUT_FILE', 'Build a deck from Markdown or CSV study notes'
    option :reverse, type: :boolean, default: false, desc: 'Add reversed copy of each basic card'
    long_desc 'Supported inputs: Markdown (.md, Q:/A: pairs or "- **Q** — A" bullets, headings become tags) ' \
              'and CSV (front,back[,tags]).'
    def import(deck_name, input_file, output_file)
      run_command Commands::Import,
                  deck_name:,
                  input_file:,
                  output_file:,
                  reverse: options[:reverse]
    end

    desc 'push DECK_NAME YAML_FILE', 'Push a YAML card file into a running Anki via AnkiConnect'
    option :url, type: :string, default: AnkiConnectClient::DEFAULT_URL, desc: 'AnkiConnect URL'
    long_desc 'Requires Anki running with the AnkiConnect add-on. Cards are added to the Basic note type; ' \
              'duplicates are skipped.'
    def push(deck_name, yaml_file)
      run_command Commands::Push,
                  deck_name:,
                  yaml_file:,
                  url: options[:url]
    end

    desc 'serve', 'Start a local web UI to preview, edit, and export decks'
    option :port, type: :numeric, default: Commands::Serve::DEFAULT_PORT, desc: 'Port to listen on'
    long_desc 'Opens a browser UI at http://localhost:<port>: paste Markdown notes or generate cards with AI, ' \
              'edit the result, and download an .apkg.'
    def serve
      run_command Commands::Serve,
                  port: options[:port],
                  provider: options[:provider]
    end

    desc 'create_ai_template TEMPLATE_FILE', 'Create a template YAML file for AI generation'
    def create_ai_template(template_file)
      run_command Commands::CreateAiTemplate, template_file:
    end

    desc 'test_api', 'Test the LLM API connection'
    option :api_key, type: :string, desc: 'OpenRouter API key (or set OPENROUTER_API_KEY env var)'
    option :model, type: :string, desc: 'AI model to use (provider default if omitted)'
    option :structured, type: :boolean, default: false, desc: 'Ask the model for strict JSON output'
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
      options[:model] || default_model_for(options[:provider])
    end

    def default_model_for(provider)
      provider.to_s == 'ollama' ? OllamaClient::DEFAULT_MODEL : DEFAULT_MODEL
    end

    # Ollama needs no key; OpenRouter falls back to the environment when the
    # --api_key option is not given. With required: false a missing key yields
    # nil (commands then skip AI generation instead of failing).
    def build_client(required: true, structured: options[:structured])
      provider = options[:provider]
      return ClientFactory.build(provider:, model: option_model) if provider.to_s == 'ollama'

      api_key = options[:api_key] || ENV.fetch('OPENROUTER_API_KEY', nil)
      return ClientFactory.build(provider:, model: option_model, api_key:, structured:) if api_key && !api_key.empty?
      return nil unless required

      raise ConfigurationError, 'OpenRouter API key is required (use --api_key or set OPENROUTER_API_KEY)'
    end
  end
end
