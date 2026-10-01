# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'
require 'tmpdir'
require 'webrick'
require 'yaml'
require_relative 'card'
require_relative 'client_factory'
require_relative 'deck_builder'
require_relative 'errors'
require_relative 'importers/markdown'
require_relative 'ui'

module AnkiGenerator
  # Localhost preview-and-export UI for the gem. Pure WEBrick + vanilla JS —
  # no build step, no framework. Mount the routes with `.mount(router)` and
  # start with WEBrick, or use Commands::Serve.
  class Server
    # Shared JSON response helpers for the servlets below.
    module ServletHelpers
      private

      def json_response(response, payload)
        response['Content-Type'] = 'application/json'
        response.status = 200
        response.body = payload.to_json
      end

      def error_response(response, error)
        response['Content-Type'] = 'application/json'
        response.status = 422
        response.body = { 'error' => error.message }.to_json
      end
    end

    # Renders the single-page editor UI.
    class PageServlet < WEBrick::HTTPServlet::AbstractServlet
      include ServletHelpers

      def do_GET(_request, response)
        response['Content-Type'] = 'text/html; charset=utf-8'
        response.body = PAGE
      end
    end

    # Parses pasted Markdown or YAML card text into the editor's card list.
    class ParseServlet < WEBrick::HTTPServlet::AbstractServlet
      include ServletHelpers
      def do_POST(request, response)
        payload = JSON.parse(request.body)
        format = payload['format'].to_s

        cards = case format
                when 'markdown'
                  Importers::Markdown.parse(payload['content'].to_s)
                when 'yaml'
                  parse_yaml(payload['content'].to_s)
                else
                  raise ValidationError, "Unknown format '#{format}' (markdown or yaml)"
                end

        json_response(response, { 'cards' => cards })
      rescue AnkiGenerator::Error, JSON::ParserError => e
        error_response(response, e)
      end

      private

      def parse_yaml(content)
        parsed = YAML.safe_load(content, permitted_classes: [Time, Date], aliases: false)
        list = parsed.is_a?(Array) ? parsed : parsed['cards'] || []
        Array(list).select { |raw| raw.is_a?(Hash) && raw['front'] && raw['back'] }
      end
    end

    # Generates cards from a prompt through the configured LLM provider.
    class GenerateServlet < WEBrick::HTTPServlet::AbstractServlet
      include ServletHelpers

      # WEBrick instantiates mounted servlets as servlet.new(server, *options),
      # so mount options arrive positionally.
      def initialize(server, options = {})
        super(server)
        @provider = options[:provider] || 'openrouter'
      end

      def do_POST(request, response)
        payload = JSON.parse(request.body)
        client = ClientFactory.build(
          provider: payload['provider'] || @provider,
          model: empty_to_nil(payload['model']),
          api_key: empty_to_nil(payload['api_key'])
        )

        cards = client.generate_multiple_flashcards(
          topics: [payload['prompt'].to_s],
          difficulty: payload['difficulty'].to_s.empty? ? 'medium' : payload['difficulty'],
          count: (payload['count'] || 10).to_i
        )

        json_response(response, { 'cards' => cards })
      rescue AnkiGenerator::Error, JSON::ParserError => e
        error_response(response, e)
      end

      private

      def empty_to_nil(value)
        value.nil? || value.to_s.empty? ? nil : value
      end
    end

    # Builds and downloads the .apkg for the edited card list.
    class ExportServlet < WEBrick::HTTPServlet::AbstractServlet
      include ServletHelpers
      def do_POST(request, response)
        payload = JSON.parse(request.body)
        deck_name = payload['deck_name'].to_s
        raise ValidationError, 'Deck name cannot be empty' if deck_name.empty?

        cards = build_cards(payload['cards'])
        raise ValidationError, 'Add at least one card before exporting' if cards.empty?

        Dir.mktmpdir('anki_generator_serve') do |dir|
          output_path = File.join(dir, "#{deck_name.gsub(/[^\w\- ]/, '_')}.apkg")
          builder = DeckBuilder.new(name: deck_name, deck_file: write_deck_file(dir, cards),
                                    ui: UI.new(File::NULL))
          builder.generate_apkg(output_path:)

          attach_apkg(response, output_path)
        end
      rescue AnkiGenerator::Error, JSON::ParserError => e
        error_response(response, e)
      end

      private

      def build_cards(raw_cards)
        Array(raw_cards).map do |raw|
          Card.new(
            front: raw['front'], back: raw['back'],
            tags: raw['tags'] || [], cloze: empty_to_nil(raw['cloze'])
          )
        end
      end

      def attach_apkg(response, output_path)
        response['Content-Type'] = 'application/octet-stream'
        response['Content-Disposition'] = "attachment; filename=\"#{File.basename(output_path)}\""
        response.body = File.binread(output_path)
      end

      def empty_to_nil(value)
        value.nil? || value.to_s.empty? ? nil : value
      end

      # DeckBuilder consumes a YAML path, so stage the edited cards in a temp
      # file inside the same temp dir the archive will live in.
      def write_deck_file(dir, cards)
        path = File.join(dir, 'deck.yaml')
        File.write(path, { 'cards' => cards.map(&:to_h) }.to_yaml)
        path
      end
    end

    PAGE = <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Anki Generator</title>
      <style>
        :root { color-scheme: light dark; }
        * { box-sizing: border-box; }
        body { font-family: -apple-system, system-ui, sans-serif; margin: 0; background: #0f1115; color: #e6e8ee; }
        header { padding: 16px 24px; border-bottom: 1px solid #262a35; }
        h1 { font-size: 18px; margin: 0; }
        main { display: grid; grid-template-columns: 380px 1fr; gap: 16px; padding: 16px 24px; }
        fieldset { border: 1px solid #262a35; border-radius: 8px; margin: 0 0 16px; padding: 12px; }
        legend { padding: 0 6px; color: #9aa3b5; font-size: 12px; text-transform: uppercase; }
        label { display: block; font-size: 12px; color: #9aa3b5; margin: 8px 0 4px; }
        input, textarea, select { width: 100%; background: #171a22; color: #e6e8ee; border: 1px solid #2c3140; border-radius: 6px; padding: 8px; font: inherit; }
        textarea { min-height: 120px; resize: vertical; font-family: ui-monospace, monospace; font-size: 13px; }
        button { background: #3b82f6; color: #fff; border: 0; border-radius: 6px; padding: 8px 14px; cursor: pointer; font-weight: 600; margin-top: 10px; }
        button.secondary { background: #2c3140; }
        button:disabled { opacity: .5; cursor: default; }
        table { width: 100%; border-collapse: collapse; font-size: 14px; }
        th, td { border-bottom: 1px solid #262a35; padding: 8px; text-align: left; vertical-align: top; }
        th { color: #9aa3b5; font-size: 12px; text-transform: uppercase; }
        td input { border: 0; background: transparent; padding: 2px; }
        .row { display: flex; gap: 8px; }
        .row > * { flex: 1; }
        #status { font-size: 13px; color: #9aa3b5; margin: 8px 0; white-space: pre-wrap; }
        .toolbar { display: flex; gap: 8px; align-items: center; margin-bottom: 8px; flex-wrap: wrap; }
        .del { background: none; border: 0; color: #ef4444; cursor: pointer; font-size: 16px; margin: 0; padding: 2px 6px; }
      </style>
      </head>
      <body>
      <header><h1>Anki Generator &mdash; preview &amp; export</h1></header>
      <main>
        <section>
          <fieldset>
            <legend>From notes</legend>
            <label>Paste Markdown (Q:/A: pairs or <code>- **Q** &mdash; A</code>)</label>
            <textarea id="md"></textarea>
            <button class="secondary" onclick="parseCards('markdown')">Parse cards</button>
          </fieldset>
          <fieldset>
            <legend>From AI</legend>
            <label>Prompt</label>
            <input id="ai-prompt" placeholder="Ruby metaprogramming basics">
            <div class="row">
              <div><label>Provider</label>
                <select id="ai-provider"><option value="openrouter">OpenRouter</option><option value="ollama">Ollama (local)</option></select></div>
              <div><label>Model (optional)</label><input id="ai-model" placeholder="default"></div>
            </div>
            <div class="row">
              <div><label>Count</label><input id="ai-count" type="number" value="10" min="1" max="50"></div>
              <div><label>Difficulty</label>
                <select id="ai-difficulty"><option>easy</option><option selected>medium</option><option>hard</option></select></div>
            </div>
            <label>OpenRouter API key (optional, else env)</label>
            <input id="ai-key" type="password">
            <button onclick="generateCards()">Generate</button>
          </fieldset>
        </section>
        <section>
          <div class="toolbar">
            <input id="deck-name" placeholder="Deck name" style="max-width:240px">
            <button class="secondary" onclick="addRow()">+ Add card</button>
            <button onclick="exportDeck()">Export .apkg</button>
          </div>
          <div id="status"></div>
          <table>
            <thead><tr><th style="width:45%">Front</th><th>Back</th><th style="width:32px"></th></tr></thead>
            <tbody id="cards"></tbody>
          </table>
        </section>
      </main>
      <script>
        const cardsBody = document.getElementById('cards');
        const statusEl = document.getElementById('status');
        const say = (msg) => { statusEl.textContent = msg || ''; };

        async function call(path, payload) {
          const res = await fetch(path, { method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(payload) });
          const data = await res.json().catch(() => ({}));
          if (!res.ok) throw new Error(data.error || ('HTTP ' + res.status));
          return data;
        }

        function addRow(card = {front: '', back: ''}) {
          const tr = document.createElement('tr');
          tr.innerHTML = '<td><input class="f"></td><td><input class="b"></td><td><button class="del" title="Remove">&times;</button></td>';
          tr.querySelector('.f').value = card.front || '';
          tr.querySelector('.b').value = card.back || '';
          tr.querySelector('.del').onclick = () => tr.remove();
          cardsBody.appendChild(tr);
        }

        function collectCards() {
          return [...cardsBody.querySelectorAll('tr')].map(tr => ({
            front: tr.querySelector('.f').value.trim(),
            back: tr.querySelector('.b').value.trim()
          })).filter(c => c.front || c.back);
        }

        async function parseCards(format) {
          say('Parsing…');
          try {
            const data = await call('/parse', { format, content: document.getElementById('md').value });
            cardsBody.innerHTML = ''; data.cards.forEach(addRow);
            say(data.cards.length + ' card(s) parsed.');
          } catch (e) { say('Error: ' + e.message); }
        }

        async function generateCards() {
          say('Generating…');
          try {
            const data = await call('/generate', {
              prompt: document.getElementById('ai-prompt').value,
              provider: document.getElementById('ai-provider').value,
              model: document.getElementById('ai-model').value,
              api_key: document.getElementById('ai-key').value,
              count: document.getElementById('ai-count').value,
              difficulty: document.getElementById('ai-difficulty').value
            });
            cardsBody.innerHTML = ''; data.cards.forEach(addRow);
            say(data.cards.length + ' card(s) generated.');
          } catch (e) { say('Error: ' + e.message); }
        }

        async function exportDeck() {
          const name = document.getElementById('deck-name').value.trim();
          if (!name) { say('Enter a deck name first.'); return; }
          say('Building .apkg…');
          try {
            const res = await fetch('/export', { method: 'POST', headers: {'Content-Type': 'application/json'},
              body: JSON.stringify({ deck_name: name, cards: collectCards() }) });
            if (!res.ok) { const data = await res.json().catch(() => ({})); throw new Error(data.error || ('HTTP ' + res.status)); }
            const blob = await res.blob();
            const a = document.createElement('a');
            a.href = URL.createObjectURL(blob); a.download = name + '.apkg'; a.click();
            URL.revokeObjectURL(a.href);
            say('Exported ' + name + '.apkg');
          } catch (e) { say('Error: ' + e.message); }
        }
      </script>
      </body>
      </html>
    HTML

    # Mounts the routes onto a WEBrick server.
    def self.mount(webrick, provider: 'openrouter')
      webrick.mount('/', PageServlet)
      webrick.mount('/parse', ParseServlet)
      webrick.mount('/generate', GenerateServlet, { provider: })
      webrick.mount('/export', ExportServlet)
    end
  end
end
