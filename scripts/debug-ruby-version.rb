#!/usr/bin/env ruby
# frozen_string_literal: true

# Debug script to check Ruby version compatibility

puts "Ruby Version: #{RUBY_VERSION}"
puts "Ruby Engine: #{RUBY_ENGINE}"
puts "Ruby Platform: #{RUBY_PLATFORM}"
puts

# Check minitest availability
begin
  require 'minitest'
  puts '✅ minitest loaded successfully'
  puts "   Version: #{Minitest::VERSION}"
rescue LoadError => e
  puts "❌ Failed to load minitest: #{e.message}"
end

# Check minitest/mock availability
begin
  require 'minitest/mock'
  puts '✅ minitest/mock loaded successfully'
rescue LoadError => e
  puts "❌ Failed to load minitest/mock: #{e.message}"
  puts '   This is expected in Ruby 3.3+ where it may be a separate gem'
end

# Check if we're in a bundled gems situation
if defined?(Gem::BUNDLED_GEMS)
  puts "\n📦 Bundled gems detected"
  puts "   Bundled gems file: #{Gem::BUNDLED_GEMS}"
end

# Show load path
puts "\n📁 Load path (first 5 entries):"
$LOAD_PATH.first(5).each_with_index do |path, i|
  puts "   #{i + 1}. #{path}"
end

# Check gem environment
puts "\n💎 Gem environment:"
puts "   Gem version: #{Gem::VERSION}"
puts "   Gem home: #{Gem.dir}"
puts "   Gem path: #{Gem.path.join(':')}"

# List minitest-related gems
puts "\n🔍 Minitest-related gems:"
Gem::Specification.find_all.select { |spec| spec.name.include?('minitest') }.each do |spec|
  puts "   #{spec.name} (#{spec.version}) - #{spec.summary}"
end

puts "\n🧪 Testing basic minitest functionality:"
begin
  require 'minitest/autorun'

  class TestBasic < Minitest::Test
    def test_basic
      assert_equal 1, 1
    end
  end

  puts '✅ Basic minitest test class created successfully'
rescue StandardError => e
  puts "❌ Failed to create basic test: #{e.message}"
end

puts "\n🎭 Testing mock functionality:"
begin
  require 'minitest/mock'

  mock = Minitest::Mock.new
  mock.expect(:call, 'result', ['arg'])
  result = mock.call('arg')
  mock.verify

  puts "✅ Mock functionality works: #{result}"
rescue StandardError => e
  puts "❌ Mock functionality failed: #{e.message}"
  puts "   #{e.backtrace.first}"
end
