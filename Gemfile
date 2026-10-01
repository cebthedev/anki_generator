# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development do
  gem 'rake', '~> 13.0'
  gem 'rubocop', '~> 1.60', require: false
  gem 'ruby-lsp', require: false
end

group :test do
  gem 'minitest', '~> 5.20'
  gem 'rack-test', '~> 2.1'
  gem 'simplecov', '~> 0.22', require: false
  gem 'webmock', '~> 3.23'
end

# Ruby 3.3+ compatibility (faraday dependency)
gem 'mutex_m' if RUBY_VERSION >= '3.3.0'
