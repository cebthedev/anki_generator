# frozen_string_literal: true

require 'rake/testtask'
require 'fileutils'

# Test tasks
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.test_files = FileList['tests/test_*.rb'].exclude('tests/test_helper.rb')
  t.verbose = true
end

desc 'Run all tests (with coverage report and floor enforced via test_helper)'
task test_all: :test

desc 'Run specific test file'
task :test_file, [:file] do |_t, args|
  if args[:file]
    ruby "-I lib tests/test_#{args[:file]}.rb"
  else
    puts 'Usage: rake test_file[file_name] (without test_ prefix)'
    puts 'Example: rake test_file[cli] runs tests/test_cli.rb'
  end
end

# Development tasks
desc 'Install dependencies'
task :install do
  sh 'bundle install'
end

desc 'Build gem'
task :build do
  sh 'gem build anki_generator.gemspec'
end

desc 'Install gem locally'
task install_local: :build do
  gem_file = Dir['anki_generator-*.gem'].last
  sh "gem install #{gem_file}"
end

desc 'Clean build artifacts'
task :clean do
  FileUtils.rm_f(Dir['*.gem'])
  FileUtils.rm_f(Dir['*.apkg'])
  FileUtils.rm_f(Dir['temp_*.yaml'])
  puts 'Cleaned build artifacts'
end

# Example and demo tasks
desc 'Create example files'
task :examples do
  FileUtils.mkdir_p('examples')

  File.write('examples/study_prompt.txt', <<~PROMPT)
    Create flashcards about Ruby programming fundamentals.
    Focus on basic syntax, data types, control structures, and object-oriented concepts.
    Make the questions practical and suitable for beginners.
  PROMPT

  File.write('examples/example_class.rb', <<~'RUBY')
    class Calculator
      attr_reader :history

      def initialize
        @history = []
      end

      def add(a, b)
        result = a + b
        @history << "#{a} + #{b} = #{result}"
        result
      end
    end
  RUBY

  File.write('examples/manual_cards.yaml', <<~YAML)
    - front: "What is a Ruby class?"
      back: "A class is a blueprint for creating objects with shared attributes and methods"

    - front: "How do you define a method in Ruby?"
      back: "Use the 'def' keyword followed by the method name and optional parameters"
  YAML

  puts 'Created example files in examples/ directory'
end

desc 'Demo: Generate cards from prompt'
task :demo_prompt do
  puts 'Demo: Generating flashcards from a simple prompt...'
  puts 'Note: This requires OPENROUTER_API_KEY environment variable'

  sh 'ruby -I lib bin/anki_generator generate_yaml "Ruby basics: variables, methods, classes" ' \
     'demo_output.yaml --count 5 --difficulty easy'
  puts 'Generated demo_output.yaml'
end

desc 'Demo: Generate cards with file attachments'
task demo_attachments: :examples do
  puts 'Demo: Generating flashcards with file attachments...'
  puts 'Note: This requires OPENROUTER_API_KEY environment variable'

  sh 'ruby -I lib bin/anki_generator prompt_to_deck examples/study_prompt.txt "Ruby Study Demo" ' \
     'demo_deck.apkg --prompt-file --attach examples/example_class.rb --count 8'
  puts 'Generated demo_deck.apkg with file attachments'
end

desc 'Demo: Test API connection'
task :demo_api do
  puts 'Testing OpenRouter API connection...'
  sh 'ruby -I lib bin/anki_generator test_api'
end

# Utility tasks
desc 'Show CLI help'
task :help do
  sh 'ruby -I lib bin/anki_generator help'
end

desc 'Show version info'
task :version do
  require_relative 'lib/anki_generator/version'
  puts "Anki Generator version: #{AnkiGenerator::VERSION}"
end

desc 'Show changelog for current version'
task :changelog do
  version = File.read('lib/anki_generator/version.rb')[/VERSION = '([^']+)'/, 1]

  if File.exist?('CHANGELOG.md')
    changelog = File.read('CHANGELOG.md')

    version_section = changelog.match(/## \[#{Regexp.escape(version)}\].*?(?=## \[|\z)/m)

    if version_section
      puts "Changelog for version #{version}:"
      puts '=' * 40
      puts version_section[0]
    else
      puts "No changelog entry found for version #{version}"
      puts 'Please update CHANGELOG.md'
    end
  else
    puts 'CHANGELOG.md not found'
  end
end

desc 'Lint code with RuboCop'
task :lint do
  sh 'rubocop --format simple --fail-level warning'
end

desc 'Auto-fix linting issues'
task :lint_fix do
  sh 'rubocop --auto-correct-all --format simple'
end

# Combined tasks
desc 'Full development setup'
task setup: %i[install examples] do
  puts 'Development environment ready!'
  puts "Run 'rake test' to run tests"
  puts "Run 'rake demo_api' to test API connection"
  puts "Run 'rake help' to see CLI options"
end

desc 'Prepare for release'
task release_prep: %i[clean lint test build] do
  puts 'Release preparation complete!'
  puts 'Gem built and tests passed'
end

task default: :test
