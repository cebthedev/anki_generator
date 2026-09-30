# Anki Generator

A Ruby tool to generate Anki .apkg files from YAML definitions with AI-powered content generation using OpenRouter and file attachment support.

## Features

- **AI-Powered Generation**: Create flashcards using OpenRouter API with multiple AI models (GPT, Claude, Llama, etc.)
- **File Attachment Support**: Attach code files, documentation, or entire directories for context-aware generation
- **Prompt File Support**: Use text files as prompts for better organization and reusability
- **Multiple Input Methods**: Generate from YAML files, direct prompts, or file attachments
- **Intelligent Content Processing**: Automatic text file detection, size limits, and binary file filtering
- **Direct Prompt-to-Deck Generation**: Create decks in one command without intermediate files
- **Sync Functionality**: Merge new AI-generated cards with existing decks
- **Flexible Configuration**: Multiple difficulty levels, context settings, and model selection
- **Comprehensive CLI**: Full command-line interface with extensive options

## Installation

**Requirements**: Ruby 3.1 or higher

1. Clone the repository
2. Install dependencies:
   ```bash
   bundle install
   ```

3. Set up your OpenRouter API key:
   ```bash
   cp .env.example .env
   # Edit .env and add your OpenRouter API key
   ```

## Usage

### Quick Start - Generate from Prompt

The fastest way to create flashcards is directly from a prompt:

```bash
# Generate flashcards and create deck in one step
./bin/anki_generator prompt_to_deck "Ruby programming basics" "Ruby Deck" ruby_deck.apkg --api_key YOUR_API_KEY

# Generate from a prompt file with code attachments
./bin/anki_generator prompt_to_deck study_prompt.txt "Code Study" code_deck.apkg --prompt-file --attach ./src --api_key YOUR_API_KEY

# Generate just the YAML file first
./bin/anki_generator generate_yaml "JavaScript fundamentals" js_cards.yaml --api_key YOUR_API_KEY --count 15

# Then create the deck
./bin/anki_generator generate "JS Deck" js_cards.yaml js_deck.apkg
```

### Traditional Usage

Generate a deck from a YAML file:

```bash
./bin/anki_generator generate "My Deck" input/input.yaml my_deck.apkg
```

### AI-Powered Generation

Create an AI generation template:

```bash
./bin/anki_generator create_ai_template my_ai_deck.yaml
```

Generate a deck with AI content:

```bash
./bin/anki_generator generate "AI Deck" my_ai_deck.yaml ai_deck.apkg --api_key YOUR_API_KEY
```

### Advanced Options

```bash
# Use a specific AI model
./bin/anki_generator prompt_to_deck "Python basics" "Python Deck" python.apkg --model anthropic/claude-sonnet-4

# Set difficulty and count
./bin/anki_generator generate_yaml "Advanced algorithms" algo.yaml --difficulty hard --count 20

# Add context for better generation
./bin/anki_generator prompt_to_deck "Machine Learning" "ML Deck" ml.apkg --context "For computer science students" --difficulty medium

# Use prompt from file
./bin/anki_generator generate_yaml prompt.txt output.yaml --prompt-file

# Attach files for context
./bin/anki_generator prompt_to_deck "Explain this code" "Code Deck" code.apkg --attach src/main.rb --attach config.yml

# Attach entire directory
./bin/anki_generator generate_yaml "Create cards about this project" project.yaml --attach ./src --attach ./docs

# Combine file prompt with attachments
./bin/anki_generator prompt_to_deck prompt.txt "My Deck" deck.apkg --prompt-file --attach ./examples

# Save intermediate YAML file
./bin/anki_generator prompt_to_deck "React hooks" "React Deck" react.apkg --save-yaml

# Sync with existing deck
./bin/anki_generator generate "My Deck" input.yaml output.apkg --sync_with existing_deck.yaml

# Test API connection
./bin/anki_generator test_api --api_key YOUR_API_KEY
```

## CLI Commands

### `prompt_to_deck` - One-Step Generation
Generate flashcards from a prompt and create the deck immediately:
```bash
anki_generator prompt_to_deck PROMPT DECK_NAME OUTPUT_FILE [options]
```

**Options:**
- `--attach FILE_OR_DIR [FILE_OR_DIR...]` - Attach files or directories for context
- `--prompt-file` - Treat PROMPT as a file path to read from
- `--save-yaml` - Save intermediate YAML file
- `--api-key API_KEY` - OpenRouter API key
- `--model MODEL` - AI model to use
- `--difficulty LEVEL` - Difficulty level (easy, medium, hard)
- `--count N` - Number of flashcards to generate
- `--context TEXT` - Additional context for better generation

### `generate_yaml` - Generate YAML from Prompt
Create a YAML file from a prompt for later use:
```bash
anki_generator generate_yaml PROMPT OUTPUT_YAML [options]
```

**Options:**
- `--attach FILE_OR_DIR [FILE_OR_DIR...]` - Attach files or directories for context
- `--prompt-file` - Treat PROMPT as a file path to read from
- `--api-key API_KEY` - OpenRouter API key
- `--model MODEL` - AI model to use
- `--difficulty LEVEL` - Difficulty level (easy, medium, hard)
- `--count N` - Number of flashcards to generate
- `--context TEXT` - Additional context for better generation

### `generate` - Create Deck from YAML
Generate an Anki deck from an existing YAML file:
```bash
anki_generator generate DECK_NAME YAML_FILE OUTPUT_FILE [options]
```

### `create_ai_template` - Create Template
Create a template YAML file for AI generation:
```bash
anki_generator create_ai_template TEMPLATE_FILE
```

### `test_api` - Test Connection
Test your OpenRouter API connection:
```bash
anki_generator test_api [options]
```

## File Attachments

The Anki Generator supports attaching files and directories to provide context for AI generation. This is particularly useful for:

- Creating flashcards about specific code files
- Generating questions based on documentation
- Learning from configuration files or data structures
- Creating study materials from existing project files

### Supported File Types

The tool automatically processes text-based files including:
- Code files: `.rb`, `.py`, `.js`, `.ts`, `.java`, `.cpp`, `.c`, `.go`, `.rs`, etc.
- Documentation: `.md`, `.txt`, `.rst`, `.adoc`, `.org`
- Configuration: `.yaml`, `.yml`, `.json`, `.xml`, `.toml`
- Web files: `.html`, `.css`, `.scss`
- Scripts: `.sh`, `.bat`, `.ps1`

### File Size Limits

- Maximum individual file size: 1MB
- Maximum total attachment size: 5MB
- Files exceeding limits are automatically skipped with warnings

### Usage Examples

```bash
# Attach a single file
./bin/anki_generator prompt_to_deck "Explain this Ruby class" "Ruby Deck" ruby.apkg --attach person.rb

# Attach multiple files
./bin/anki_generator generate_yaml "Create cards about these configs" config.yaml --attach database.yml --attach routes.rb --attach Gemfile

# Attach entire directories (processes all text files)
./bin/anki_generator prompt_to_deck "Study this codebase" "Project Deck" project.apkg --attach ./src --attach ./lib

# Combine with prompt files
./bin/anki_generator generate_yaml study_prompt.txt output.yaml --prompt-file --attach ./examples --attach README.md

# Use context and attachments together
./bin/anki_generator prompt_to_deck "Advanced Ruby patterns" "Advanced Ruby" advanced.apkg \
  --attach ./lib --context "Focus on metaprogramming and DSL patterns" --difficulty hard
```

### How Attachments Work

1. **File Processing**: The tool scans attached files and directories for text-based content
2. **Content Inclusion**: File contents are included in the AI prompt with clear file boundaries
3. **Smart Generation**: The AI uses the file content to create more accurate and specific flashcards
4. **Automatic Filtering**: Binary files and oversized files are automatically skipped

### Best Practices

- **Be Specific**: Attach only relevant files to avoid overwhelming the AI with too much context
- **Use Descriptive Prompts**: Combine attachments with clear prompts about what you want to learn
- **Organize Files**: Group related files in directories for easier attachment
- **Check File Sizes**: Large files will be skipped, so break them down if needed

## YAML Formats

### Traditional Format

```yaml
- front: "What is Big O notation?"
  back: "Big O notation describes the limiting behavior of a function..."

- front: "Define a graph"
  back: "A graph is a collection of vertices connected by edges"
```

### AI Generation Format

```yaml
ai_generation:
  topics:
    - "Ruby programming fundamentals"
    - "Object-oriented programming"
  context: "Beginner-friendly programming concepts"
  difficulty: "medium"  # easy, medium, hard
  count: 10
  save_generated: true

# Optional manual cards
cards:
  - front: "Manual question"
    back: "Manual answer"
```

## Configuration

### Environment Variables

- `OPENROUTER_API_KEY`: Your OpenRouter API key
- `OPENROUTER_DEFAULT_MODEL`: Default model to use (optional)

### Supported Models

The tool supports all models available through OpenRouter:

- OpenAI: `openai/gpt-4o-mini` (default), `openai/gpt-4o`
- Anthropic: `anthropic/claude-sonnet-4`, `anthropic/claude-haiku-4`
- Meta: `meta-llama/llama-3.3-70b-instruct`
- And many more...

## Examples

### Quick Examples

```bash
# Generate 10 Python flashcards
./bin/anki_generator prompt_to_deck "Python data structures" "Python Deck" python.apkg

# Generate 20 hard-level algorithm cards
./bin/anki_generator generate_yaml "Sorting algorithms" algo.yaml --difficulty hard --count 20

# Create deck with context
./bin/anki_generator prompt_to_deck "React components" "React Deck" react.apkg --context "For beginners learning React"

# Study a specific code file
./bin/anki_generator prompt_to_deck "Create flashcards about this Ruby class" "Ruby Class Deck" ruby_class.apkg --attach person.rb

# Learn from project documentation
./bin/anki_generator generate_yaml "Study this API documentation" api_study.yaml --attach README.md --attach docs/api.md

# Comprehensive project study
./bin/anki_generator prompt_to_deck "Help me understand this codebase structure and patterns" "Codebase Study" study.apkg \
  --attach ./src --attach ./lib --attach README.md --context "Focus on architecture and design patterns"
```

### File Attachment Examples

```bash
# Study a single Ruby file
./bin/anki_generator prompt_to_deck "What does this code do?" "Code Analysis" analysis.apkg --attach calculator.rb

# Learn from configuration files
./bin/anki_generator generate_yaml "Explain these configurations" config_study.yaml --attach config/database.yml --attach config/routes.rb

# Study an entire project
./bin/anki_generator prompt_to_deck "Create comprehensive study cards for this project" "Project Study" project.apkg \
  --attach ./app --attach ./lib --attach Gemfile --attach README.md

# Use prompt file with attachments
echo "Create flashcards focusing on the class structure and methods in the attached files" > study_prompt.txt
./bin/anki_generator generate_yaml study_prompt.txt class_study.yaml --prompt-file --attach ./models

# Advanced usage with multiple options
./bin/anki_generator prompt_to_deck prompt_file.txt "Advanced Study" advanced.apkg \
  --prompt-file --attach ./src --attach ./docs --difficulty hard --count 25 \
  --context "Focus on advanced patterns and best practices" --save-yaml
```

### Example YAML Files

See the `input/` directory for example YAML files, or create examples with `rake examples`:

- `examples/study_prompt.txt` - Example prompt file
- `examples/example_class.rb` - Example Ruby code for attachments
- `examples/manual_cards.yaml` - Traditional format example
- `input/ai_generation_example.yaml` - AI generation example
- `input/algorithms_ai.yaml` - Computer science topics
- `input/input.yaml.example` - Traditional format

## Development

### Quick Start for Developers

The repo pins Ruby via `.ruby-version` (3.3). With rbenv/asdf installed:

```bash
# Clone and setup
git clone <repository-url>
cd anki_generator
rake setup                     # Install dependencies and create examples

# Run tests (coverage report in coverage/, 75% line floor enforced)
rake test                      # Run all tests
rake test_file[cli]           # Run specific test

# Lint (zero offenses enforced — CI fails otherwise)
rake lint
rake lint_fix                 # Auto-correct safe offenses

# Try the examples
rake demo_api                 # Test API connection
rake examples                 # Create example files
rake demo_attachments         # Demo with file attachments
```

### GitHub Actions CI/CD

The project includes GitHub Actions workflows:

- **`ruby.yml`** - Main CI pipeline: tests on Ruby 3.1–3.4 plus a RuboCop lint gate
- **`release.yml`** - Automated releases when tags are pushed
- **`manual-test.yml`** - Manual workflow for testing specific scenarios

To trigger a release:
```bash
git tag v1.2.0
git push origin v1.2.0
```

### Running Tests

```bash
# Run all tests (SimpleCov runs by default; the suite fails below 75% line coverage)
rake test

# Run specific test file
rake test_file[cli]              # runs tests/test_cli.rb
rake test_file[file_processor]   # runs tests/test_file_processor.rb
```
### Development Commands

```bash
# Setup development environment
rake setup                      # Install deps and create examples

# Build and install
rake build                      # Build gem
rake install_local             # Build and install gem locally
rake clean                     # Clean build artifacts

# Code quality
rake lint                      # Run RuboCop linter
rake lint_fix                  # Auto-fix linting issues

# Demos and examples
rake examples                  # Create example files
rake demo_prompt              # Demo prompt generation
rake demo_attachments         # Demo file attachment features
rake demo_api                 # Test API connection

# Utilities
rake help                     # Show CLI help
rake version                  # Show version info
rake changelog                # Show changelog for current version
rake release_prep             # Prepare for release
```

### Project Structure

```
├── lib/
│   ├── anki_generator.rb      # Main generator class
│   ├── openrouter_client.rb   # OpenRouter API client
│   ├── anki_cli.rb           # CLI interface
│   └── file_processor.rb     # File attachment processing
├── bin/
│   └── anki_generator         # CLI executable
├── tests/                     # Test files
├── input/                     # Example YAML files
└── README.md
```

## API Integration

The tool integrates with OpenRouter to provide access to multiple AI models. You can:

1. Generate flashcards on any topic
2. Specify difficulty levels
3. Provide context for better generation
4. Choose from various AI models
5. Control the number of cards generated

## Sync Functionality

The sync feature allows you to:

- Merge new AI-generated cards with existing manual cards
- Prevent duplicate cards (based on front text)
- Maintain version control of your flashcard sets
- Incrementally build large decks

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Update CHANGELOG.md with your changes
6. Submit a pull request

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed version history and changes.

## License

MIT License - see LICENSE file for details.