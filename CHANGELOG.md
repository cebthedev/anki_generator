# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-09-30

### Added
- **Markdown & CSV importers** (`AnkiGenerator::Importers::Markdown` / `Importers::Csv`) — turn study notes into decks:
  - Markdown: `Q:`/`A:` pairs, `- **front** — back` bullets, headings become tags
  - CSV: `front,back[,tags]` (tags pipe-separated)
  - New command: `anki_generator import DECK_NAME INPUT_FILE OUTPUT_FILE [--reverse]`
- **Cloze deletion cards** — YAML cards with a `cloze:` key (`cloze: "{{c1::Paris}} is the capital of {{c2::France}}"`) export as a proper Anki cloze note; one card per `{{cN::...}}` ordinal, with a dedicated `AnkiGenerator Cloze` model in the package
- **Per-card tags** — `tags: [ruby, basics]` in YAML lands in the note's tag column; `--reverse` and importers compose with tags
- **Reverse cards** — `--reverse` on `generate`/`import` appends a front↔back copy of every basic card (cloze cards are skipped)
- **Parallel AI generation** — `--jobs N` on `generate` fans one API call per topic out across N threads (Mutex + Queue worker pool)
- **Ollama provider** — `--provider ollama` talks to a local Ollama server (`OLLAMA_URL`, default `http://localhost:11434`, no API key); provider selection unified behind `AnkiGenerator::ClientFactory`
- **Automatic retries** — Faraday retry middleware on OpenRouter (3 attempts, exponential backoff, honors `Retry-After` on 429/5xx)
- **Structured output** — `--structured` requests JSON mode (`response_format: json_object`) from providers that support it
- **AnkiConnect push** — `anki_generator push DECK_NAME YAML_FILE` sends cards straight into a running Anki (`AnkiConnect` addon, default `http://localhost:8765`), reporting added/duplicate counts
- **Web UI** — `anki_generator serve [--port]` starts a localhost editor (WEBrick, no build step): paste Markdown/YAML, generate via AI, edit the card table, download `.apkg`

### Changed
- `--model` now defaults per provider (`OllamaClient::DEFAULT_MODEL` for Ollama, `gpt-4o-mini` for OpenRouter) instead of a single global default
- OpenRouter client accepts `structured:` and retry configuration; Ollama client mirrors the same interface

### Technical
- Test suite: 131 tests, 415 assertions, 96.85% line coverage (floor remains 75%)
- RuboCop zero offenses; `Metrics/ClassLength` / `Naming/MethodName` exclusions documented for the WEBrick servlet contract and the static HTML page heredoc
- `.apkg` writer uses per-table id sequences (`@note_seq`/`@card_seq`) — fixes a primary-key collision when a cloze note expands into multiple card rows

## [1.2.0] - 2026-09-30

### Breaking
- All classes are now namespaced under `AnkiGenerator::` (`AnkiGenerator::DeckBuilder`, `AnkiGenerator::OpenRouterClient`, `AnkiGenerator::FileProcessor`, `AnkiGenerator::CLI`)
- Library API returns `AnkiGenerator::Card` value objects instead of raw hashes (`card.front` / `card.back`)
- `AnkiGenerator` class renamed to `AnkiGenerator::DeckBuilder`; `sync_with_existing_deck` is now `sync_with`
- Default model changed from the retired `openai/gpt-3.5-turbo` to `openai/gpt-4o-mini`

### Added
- Native `.apkg` writer (`AnkiGenerator::ApkgWriter` + `AnkiGenerator::ApkgSchema`) — replaces the unmaintained `anki2` gem and its deprecated sqlite3 bind-param style
- Error hierarchy: `AnkiGenerator::Error` with `ConfigurationError`, `ApiError`, `ResponseParseError`, `ValidationError`, `FileProcessingError`
- `AnkiGenerator::UI` presentation boundary — library code no longer writes to `$stdout` directly; commands accept an injectable UI for quiet/testable output
- `AnkiGenerator::PromptBuilder` — prompt construction extracted from the HTTP client and unit-tested
- `anki_generator version` command
- CLI errors are reported as clean messages with exit code 1 instead of raw backtraces
- Faraday request timeouts (10s open / 120s read)
- Resilient JSON parsing: markdown fences and model commentary are stripped before parsing
- `.ruby-version` / `.tool-versions` pinned to Ruby 3.3
- SimpleCov coverage (line floor 75%) and WebMock-based HTTP tests

### Fixed
- **API URL bug**: the client posted to `/chat/completions` (leading slash replaced the base path), dropping `/api/v1` — every AI request would have 404'd
- `prompt_to_deck` no longer sends the prompt through the API a second time when building the deck from generated cards
- `prompt_to_deck` temp files no longer leak `temp_<timestamp>.yaml` into the working directory (uses `Tempfile`)
- Deck YAML is loaded with `YAML.safe_load_file` (aliases rejected, typed errors on bad input)
- Sync deduplication is now case-insensitive and trims whitespace
- Previously dead test methods (defined outside their test classes) are collected and run — test count 38 → 80

### Technical
- Thor CLI is now a thin shell over `AnkiGenerator::Commands::*` service objects with dependency injection
- RuboCop enforced in CI with zero offenses (`rake lint`)
- HTTP client tested with WebMock against real request shapes
- Test suite: 80 tests, 284 assertions

## [1.1.0] - 2026-01-01

### Added
- **File Attachment Support**: Attach individual files or entire directories for context-aware flashcard generation
- **Prompt File Support**: Use text files as prompts instead of command-line strings
- **Intelligent File Processing**: Automatic text file detection with support for 20+ file types
- **File Size Management**: Configurable limits (1MB per file, 5MB total) with automatic filtering
- **Enhanced CLI Options**: 
  - `--attach` option for file/directory attachments
  - `--prompt-file` option to read prompts from files
- **Comprehensive Test Suite**: Added `test_file_processor.rb` with full coverage
- **Enhanced Rake Tasks**: 15+ development tasks including demos, examples, and utilities
- **Developer Experience**: 
  - `rake examples` - Create example files for testing
  - `rake demo_attachments` - Demo file attachment features
  - `rake setup` - Full development environment setup

### Enhanced
- **OpenRouter Client**: Extended to support file attachments in AI prompts
- **Anki Generator**: Updated to pass attachments through the generation pipeline
- **CLI Interface**: Both `generate_yaml` and `prompt_to_deck` commands support new options
- **Documentation**: Comprehensive README updates with file attachment examples
- **Error Handling**: Improved file processing with detailed warnings and graceful failures

### Technical
- Added `FileProcessor` class for robust file and directory handling
- Enhanced prompt building with attachment content integration
- Maintained full backward compatibility with existing functionality
- All tests passing (38 tests, 128 assertions)

## [1.0.0] - 2025-12-XX

### Added
- **AI-Powered Generation**: OpenRouter API integration with multiple model support
- **Direct Prompt-to-Deck**: One-command flashcard generation from prompts
- **Multiple Input Methods**: Support for YAML files and direct prompts
- **Sync Functionality**: Merge new AI-generated cards with existing decks
- **Comprehensive CLI**: Full command-line interface with Thor
- **Model Selection**: Support for GPT, Claude, Llama, and other OpenRouter models
- **Difficulty Levels**: Easy, medium, hard difficulty settings
- **Context Support**: Additional context for better AI generation
- **YAML Formats**: Both traditional and AI-generation YAML formats

### Core Features
- `prompt_to_deck` - Generate flashcards and create deck in one step
- `generate_yaml` - Generate YAML from prompts for later use
- `generate` - Create Anki decks from YAML files
- `create_ai_template` - Create template files for AI generation
- `test_api` - Test OpenRouter API connection

### Technical
- Built with Ruby, Thor, Faraday, and anki2 gem
- Comprehensive test suite with minitest
- Environment variable support with dotenv
- Flexible configuration and error handling

## [0.x.x] - Earlier Versions

### Initial Development
- Basic YAML to Anki deck conversion
- Simple flashcard generation
- Core functionality development

---

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions  
- **PATCH** version for backwards-compatible bug fixes

## Contributing

When contributing, please:
1. Update this changelog with your changes
2. Follow the existing format and categorization
3. Add entries under "Unreleased" section
4. Move entries to versioned section when releasing