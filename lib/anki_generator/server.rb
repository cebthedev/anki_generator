# frozen_string_literal: true

require 'json'
require 'sinatra/base'
require_relative 'apkg_exporter'
require_relative 'client_factory'
require_relative 'errors'
require_relative 'importers/markdown'
require_relative 'importers/yaml'

module AnkiGenerator
  # Localhost preview-and-export UI for the gem, as a modular Sinatra app.
  # Thin controllers only: parsing delegates to Importers, export to
  # ApkgExporter, generation to ClientFactory. The page lives in
  # server/public/index.html (plain static HTML + vanilla JS).
  class Server < Sinatra::Base
    set :root, File.dirname(__FILE__)
    set :default_provider, nil
    set :protection, except: :json_csrf

    get '/' do
      send_file File.expand_path('server/public/index.html', __dir__)
    end

    post '/parse' do
      payload = json_payload!
      format = payload['format'].to_s

      cards = case format
              when 'markdown'
                Importers::Markdown.parse(payload['content'].to_s)
              when 'yaml'
                Importers::Yaml.parse(payload['content'].to_s)
              else
                raise ValidationError, "Unknown format '#{format}' (markdown or yaml)"
              end

      json_response(cards:)
    rescue AnkiGenerator::Error => e
      error_json(e.message)
    end

    post '/generate' do
      payload = json_payload!
      client = ClientFactory.build(
        provider: payload['provider'] || settings.default_provider,
        model: empty_to_nil(payload['model']),
        api_key: empty_to_nil(payload['api_key'])
      )

      cards = client.generate_multiple_flashcards(
        topics: [payload['prompt'].to_s],
        difficulty: payload['difficulty'].to_s.empty? ? 'medium' : payload['difficulty'],
        count: (payload['count'] || 10).to_i
      )

      json_response(cards:)
    rescue AnkiGenerator::Error => e
      error_json(e.message)
    end

    post '/export' do
      payload = json_payload!
      result = ApkgExporter.export(deck_name: payload['deck_name'].to_s, cards: payload['cards'])

      content_type result[:content_type]
      headers 'Content-Disposition' => %(attachment; filename="#{result[:filename]}")
      result[:bytes]
    rescue AnkiGenerator::Error => e
      error_json(e.message)
    end

    private

    # Parses the request body as JSON once. Malformed payloads halt with 400.
    def json_payload!
      body = request.body.read
      JSON.parse(body.empty? ? '{}' : body)
    rescue JSON::ParserError => e
      halt 400, { 'Content-Type' => 'application/json' }, { error: e.message }.to_json
    end

    def json_response(payload)
      content_type :json
      payload.to_json
    end

    def error_json(message, status = 422)
      content_type :json
      status status
      { error: message }.to_json
    end

    def empty_to_nil(value)
      value.nil? || value.to_s.empty? ? nil : value
    end
  end
end
