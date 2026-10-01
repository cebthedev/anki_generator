# frozen_string_literal: true

require 'webrick'
require_relative '../server'
require_relative '../ui'

module AnkiGenerator
  module Commands
    # `anki_generator serve` — start the local preview/export web UI.
    class Serve
      DEFAULT_PORT = 8787

      def initialize(port: DEFAULT_PORT, provider: 'openrouter', ui: UI.new)
        @port = port
        @provider = provider
        @ui = ui
      end

      # Blocks until the server is stopped (Ctrl+C).
      def run
        server = build_server
        Server.mount(server, provider: @provider)

        @ui.info("Anki Generator UI available at http://localhost:#{@port}")
        @ui.info('Press Ctrl+C to stop')

        trap('INT') { server.shutdown }
        server.start
      ensure
        server&.shutdown
      end

      # Starts the server on an ephemeral port in a background thread and
      # returns [server, port]; used by tests and embedding.
      def self.start_background(**kwargs)
        command = new(**kwargs)
        server = command.send(:build_server)
        Server.mount(server, provider: kwargs[:provider] || 'openrouter')
        thread = Thread.new { server.start }
        Thread.pass until server.status == :Running
        [server, server.config[:Port], thread]
      end

      private

      def build_server
        WEBrick::HTTPServer.new(
          BindAddress: '127.0.0.1',
          Port: @port,
          Logger: WEBrick::Log.new(File::NULL),
          AccessLog: []
        )
      end
    end
  end
end
