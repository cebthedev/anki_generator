# frozen_string_literal: true

require_relative 'lib/anki_generator/version'

Gem::Specification.new do |spec|
  spec.name          = 'anki_generator'
  spec.version       = AnkiGenerator::VERSION
  spec.authors       = ['Ceb']
  spec.email         = ['ceeb.developer@gmail.com']
  spec.summary       = 'AI-powered Anki flashcard generator with file attachment support'
  spec.description   = 'A command-line tool that generates Anki flashcard decks (.apkg) from YAML files, direct prompts, or file attachments. Features AI-powered content generation using the OpenRouter API with support for multiple models (GPT, Claude, Llama), file and directory attachment processing for context-aware generation, prompt file support, intelligent content filtering, and flexible deck management with sync capabilities.'
  spec.homepage      = 'https://github.com/pinkfloydsito/anki_generator'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |file|
    file.start_with?('tests/', 'scripts/', '.github/', '.kiro/') ||
      file.match?(/\.gem\z/) || file == '.env.example'
  end
  spec.bindir        = 'bin'
  spec.executables   = ['anki_generator']
  spec.require_paths = ['lib']

  spec.add_dependency 'dotenv', '~> 2.8'
  spec.add_dependency 'faraday', '~> 2.0'
  spec.add_dependency 'faraday-retry', '~> 2.0'
  spec.add_dependency 'json', '~> 2.0'
  spec.add_dependency 'rubyzip', '>= 2.3', '< 3.0'
  spec.add_dependency 'sqlite3', '>= 1.6', '< 3.0'
  spec.add_dependency 'thor', '~> 1.2'
  spec.add_dependency 'webrick', '>= 1.8'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata = {
    'homepage_uri' => spec.homepage,
    'source_code_uri' => spec.homepage,
    'changelog_uri' => "#{spec.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{spec.homepage}/issues",
    'documentation_uri' => "#{spec.homepage}/blob/main/README.md",
    'rubygems_mfa_required' => 'true'
  }
end
