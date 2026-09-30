# frozen_string_literal: true

require 'pathname'
require_relative 'errors'
require_relative 'ui'

module AnkiGenerator
  # Handles file and directory processing for attachments and prompt files.
  class FileProcessor
    # Supported text file extensions
    TEXT_EXTENSIONS = %w[
      .txt .md .rb .py .js .ts .java .cpp .c .h .hpp .css .html .xml .json
      .yaml .yml .sql .sh .bat .ps1 .php .go .rs .swift .kt .scala .clj
      .hs .elm .ex .exs .erl .pl .r .m .tex .org .rst .adoc
    ].freeze

    # Maximum file size in bytes (1MB)
    MAX_FILE_SIZE = 1_048_576

    # Maximum total content size (5MB)
    MAX_TOTAL_SIZE = 5_242_880

    class << self
      def process_attachments(paths, ui: UI.new($stderr))
        return [] if paths.nil? || paths.empty?

        attachments = []
        total_size = 0

        paths.each do |path_str|
          candidates = candidates_for(path_str, ui:)
          attachments, total_size = take_up_to_budget(candidates, attachments, total_size, ui)
        end

        ui.info("📎 Processed #{attachments.length} file(s) (#{format_size(total_size)})") if attachments.any?
        attachments
      end

      # Resolves one CLI path argument to the list of attachments it contributes:
      # a directory contributes all readable text files inside it, a file
      # contributes itself. Unusable paths warn and contribute nothing.
      def candidates_for(path_str, ui:)
        path = Pathname.new(path_str)

        unless path.exist?
          ui.warn("Path does not exist: #{path_str}")
          return []
        end

        return process_directory(path, ui:) if path.directory?

        if path.file?
          attachment = process_file(path, ui:)
          return [attachment].compact
        end

        ui.warn("Path is neither file nor directory: #{path_str}")
        []
      end

      def process_directory(dir_path, ui: UI.new($stderr))
        dir_path.children.filter_map do |child|
          process_file(child, ui:) if child.file?
        end
      end

      def process_file(file_path, ui: UI.new($stderr))
        if file_path.size > MAX_FILE_SIZE
          ui.warn("File too large, skipping: #{file_path} (#{format_size(file_path.size)})")
          return nil
        end

        unless text_file?(file_path)
          ui.warn("Non-text file, skipping: #{file_path}")
          return nil
        end

        content = read_content(file_path, ui:)
        return nil unless content

        {
          filename: file_path.basename.to_s,
          path: file_path.to_s,
          content:
        }
      end

      def text_file?(file_path)
        ext = file_path.extname.downcase
        return true if TEXT_EXTENSIONS.include?(ext)

        # Files without an extension are treated as text only if the name looks
        # like a plain-text script (e.g. Gemfile, Rakefile).
        return false if file_path.extname.empty? && file_path.basename.to_s !~ /^[A-Z_]+$/

        # Fall back to sniffing for null bytes, which indicate binary content.
        !file_path.read(512, encoding: 'BINARY').include?("\x00")
      rescue StandardError
        false
      end

      def format_size(bytes)
        if bytes < 1024
          "#{bytes} B"
        elsif bytes < 1024 * 1024
          "#{(bytes / 1024.0).round(1)} KB"
        else
          "#{(bytes / (1024.0 * 1024)).round(1)} MB"
        end
      end

      def read_prompt_from_file(file_path)
        path = Pathname.new(file_path)
        raise FileProcessingError, "Prompt file does not exist: #{file_path}" unless path.exist?
        raise FileProcessingError, "Prompt path is not a file: #{file_path}" unless path.file?

        content = path.read(encoding: 'UTF-8').strip
        raise FileProcessingError, "Prompt file is empty: #{file_path}" if content.empty?

        content
      rescue FileProcessingError
        raise
      rescue StandardError => e
        raise FileProcessingError, "Could not read prompt file #{file_path}: #{e.message}"
      end

      private

      # Appends candidates to attachments while the total-size budget allows,
      # warning and stopping once the budget is exhausted.
      def take_up_to_budget(candidates, attachments, total_size, ui)
        candidates.each do |attachment|
          if total_size + attachment[:content].bytesize > MAX_TOTAL_SIZE
            ui.warn("Total attachment size limit reached. Skipping #{attachment[:filename]}")
            next
          end

          attachments << attachment
          total_size += attachment[:content].bytesize
        end
        [attachments, total_size]
      end

      # NOTE: files larger than MAX_FILE_SIZE never reach this method (they are
      # rejected in process_file), so no post-read truncation is needed.
      def read_content(file_path, ui:)
        file_path.read(encoding: 'UTF-8')
      rescue StandardError => e
        ui.warn("Could not read file #{file_path}: #{e.message}")
        nil
      end
    end
  end
end
