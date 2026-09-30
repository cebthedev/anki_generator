# frozen_string_literal: true

require_relative 'test_helper'

class FileProcessorTest < Minitest::Test
  include TestHelpers

  def setup
    @temp_dir = Dir.mktmpdir('file_processor_test')
    @ui = silence_ui
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def process(paths, **opts)
    AnkiGenerator::FileProcessor.process_attachments(paths, ui: @ui, **opts)
  end

  def create_temp_file(content, filename = nil, extension = '.txt')
    if filename
      file_path = File.join(@temp_dir, filename)
      File.write(file_path, content)
      file_path
    else
      file = Tempfile.new(['test', extension], @temp_dir)
      file.write(content)
      file.close
      file.path
    end
  end

  def test_process_single_text_file
    content = "This is a test file\nwith multiple lines"
    file_path = create_temp_file(content, 'test.txt')

    attachments = process([file_path])

    assert_equal 1, attachments.length
    attachment = attachments.first
    assert_equal 'test.txt', attachment[:filename]
    assert_equal file_path, attachment[:path]
    assert_equal content, attachment[:content]
  end

  def test_process_multiple_files
    file1_path = create_temp_file('First file content', 'file1.rb')
    file2_path = create_temp_file('Second file content', 'file2.py')

    attachments = process([file1_path, file2_path])

    assert_equal 2, attachments.length
    assert_equal 'First file content', attachments.find { |a| a[:filename] == 'file1.rb' }[:content]
    assert_equal 'Second file content', attachments.find { |a| a[:filename] == 'file2.py' }[:content]
  end

  def test_process_directory_skips_binary
    create_temp_file('File 1 content', 'file1.txt')
    create_temp_file('File 2 content', 'file2.md')
    create_temp_file("Binary \x00 content", 'binary.exe')

    attachments = process([@temp_dir])

    filenames = attachments.map { |a| a[:filename] }
    assert_includes filenames, 'file1.txt'
    assert_includes filenames, 'file2.md'
    refute_includes filenames, 'binary.exe'
  end

  def test_text_file_detection
    %w[.txt .md .rb .py .js .json .yaml .yml].each do |ext|
      assert AnkiGenerator::FileProcessor.text_file?(Pathname.new("test#{ext}")), "#{ext} should be text"
    end

    binary_path = create_temp_file("\x00\x01\x02", 'test.exe')
    refute AnkiGenerator::FileProcessor.text_file?(Pathname.new(binary_path))
  end

  def test_file_size_limits
    large_path = create_temp_file('x' * (AnkiGenerator::FileProcessor::MAX_FILE_SIZE + 1000), 'large.txt')
    assert_empty process([large_path])
  end

  def test_total_size_limit
    half = AnkiGenerator::FileProcessor::MAX_FILE_SIZE / 2
    paths = (1..11).map { |i| create_temp_file('x' * half, "file#{i}.txt") }

    attachments = process(paths)

    assert attachments.length < paths.length, 'Should stop before processing all files'
    total_size = attachments.sum { |a| a[:content].bytesize }
    assert total_size <= AnkiGenerator::FileProcessor::MAX_TOTAL_SIZE
  end

  def test_warns_about_nonexistent_path
    io = StringIO.new
    AnkiGenerator::FileProcessor.process_attachments(['nonexistent_file.txt'], ui: AnkiGenerator::UI.new(io))

    assert_includes io.string, 'nonexistent_file.txt'
  end

  def test_empty_paths
    assert_empty process([])
    assert_empty process(nil)
  end

  def test_read_prompt_from_file_strips_content
    prompt_file = create_temp_file("  Prompt with surrounding whitespace  \n", 'prompt.txt')
    assert_equal 'Prompt with surrounding whitespace', AnkiGenerator::FileProcessor.read_prompt_from_file(prompt_file)
  end

  def test_read_prompt_from_nonexistent_file_raises_typed_error
    assert_raises(AnkiGenerator::FileProcessingError) do
      AnkiGenerator::FileProcessor.read_prompt_from_file('nonexistent_prompt.txt')
    end
  end

  def test_read_prompt_from_empty_file_raises_typed_error
    empty_file = create_temp_file('', 'empty_prompt.txt')
    assert_raises(AnkiGenerator::FileProcessingError) do
      AnkiGenerator::FileProcessor.read_prompt_from_file(empty_file)
    end
  end

  def test_read_prompt_from_directory_raises_typed_error
    assert_raises(AnkiGenerator::FileProcessingError) do
      AnkiGenerator::FileProcessor.read_prompt_from_file(@temp_dir)
    end
  end

  def test_format_size
    fp = AnkiGenerator::FileProcessor
    assert_equal '500 B', fp.format_size(500)
    assert_equal '1.5 KB', fp.format_size(1536)
    assert_equal '2.0 MB', fp.format_size(2_097_152)
  end

  def test_mixed_file_and_directory_processing
    individual = create_temp_file('Individual file content', 'individual.txt')
    create_temp_file('Dir file 1', 'dir_file1.rb')
    create_temp_file('Dir file 2', 'dir_file2.py')

    attachments = process([individual, @temp_dir])
    filenames = attachments.map { |a| a[:filename] }

    assert_includes filenames, 'individual.txt'
    assert_includes filenames, 'dir_file1.rb'
    assert_includes filenames, 'dir_file2.py'
  end

  def test_multibyte_content_is_counted_in_bytes
    # 600 two-byte characters = 1200 bytes; must not trip the size gate.
    path = create_temp_file('é' * 600, 'utf8.txt')

    attachments = process([path])

    assert_equal 1, attachments.length
    assert_equal 1200, attachments.first[:content].bytesize
  end
end
