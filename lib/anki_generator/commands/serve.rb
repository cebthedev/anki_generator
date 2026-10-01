# frozen_string_literal: true

require 'stringio'
require 'webrick'
require_relative '../server'
require_relative '../ui'

begin
  require 'rackup'
  require 'rackup/handler/webrick'
rescue LoadError
  # rackup gem not installed (it is not in the lockfile) — the small adapter
  # below bridges WEBrick to the Rack app instead.
end

module AnkiGenerator
  module Commands
    # `anki_generator serve` — start the local preview/export web UI.
    class Serve
      DEFAULT_PORT = 8787

      def initialize(port: DEFAULT_PORT, provider: nil, ui: UI.new)
        @port = port
        @provider = provider
        @ui = ui
      end

      # Blocks until the server is stopped (Ctrl+C).
      def run
        AnkiGenerator::Server.set(:default_provider, @provider)

        @ui.info("Anki Generator UI available at http://localhost:#{@port}")
        @ui.info('Press Ctrl+C to stop')

        if defined?(Rackup::Handler::WEBrick)
          Rackup::Handler::WEBrick.run(
            AnkiGenerator::Server,
            Host: '127.0.0.1', Port: @port,
            AccessLog: [], Logger: WEBrick::Log.new(File::NULL)
          )
        else
          run_webrick
        end
      end

      private

      def run_webrick
        server = WEBrick::HTTPServer.new(
          BindAddress: '127.0.0.1',
          Port: @port,
          Logger: WEBrick::Log.new(File::NULL),
          AccessLog: []
        )
        server.mount('/', RackServlet, AnkiGenerator::Server)
        trap('INT') { server.shutdown }
        server.start
      ensure
        server&.shutdown
      end

      # Minimal WEBrick -> Rack bridge used when the rackup gem is unavailable.
      class RackServlet < WEBrick::HTTPServlet::AbstractServlet
        def initialize(server, app)
          super(server)
          @app = app
        end

        def service(request, response)
          status, headers, body = @app.call(rack_env(request))
          response.status = status
          headers.each do |key, value|
            next if key.start_with?('rack.')

            response[key] = value.is_a?(Array) ? value.join(', ') : value.to_s
          end
          response.body = +''
          body.each { |part| response.body << part.to_s }
          body.close if body.respond_to?(:close)
        end

        private

        def rack_env(request)
          env = request.meta_vars
          env['CONTENT_TYPE'] ||= env.delete('Content-Type')
          env['CONTENT_LENGTH'] ||= env.delete('Content-Length')
          env.update(
            'rack.version' => Rack::RELEASE,
            'rack.input' => StringIO.new(request.body.to_s),
            'rack.errors' => $stderr,
            'rack.url_scheme' => request.ssl? ? 'https' : 'http'
          )
          env
        end
      end
    end
  end
end
