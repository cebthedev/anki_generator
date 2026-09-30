# frozen_string_literal: true

module AnkiGenerator
  # Presentation boundary for user-facing output. Commands and utilities emit
  # through a UI instance instead of writing to $stdout directly, which keeps
  # the library quiet when embedded and makes output assertions trivial in tests.
  class UI
    def initialize(io = $stdout)
      @io = io
    end

    def info(message)
      @io.puts(message)
    end

    def success(message)
      @io.puts("✅ #{message}")
    end

    def warn(message)
      @io.puts("⚠️  #{message}")
    end

    def error(message)
      @io.puts("❌ #{message}")
    end
  end
end
