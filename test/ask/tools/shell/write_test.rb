# frozen_string_literal: true

require_relative "../../../test_helper"
require "tmpdir"

module Ask
  module Tools
    class WriteTest < Minitest::Test
      def setup
        @tool = Write.new
        @tmpdir = Dir.mktmpdir("write_test")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir)
      end

      def test_tool_name
        assert_equal "write", @tool.name
      end

      def test_write_file
        path = File.join(@tmpdir, "test.txt")
        result = @tool.call(path: path, content: "hello world")
        assert_predicate result, :ok?
        assert_equal "hello world", File.read(path)
      end

      def test_write_creates_parent_dirs
        path = File.join(@tmpdir, "a", "b", "c", "test.txt")
        result = @tool.call(path: path, content: "nested")
        assert_predicate result, :ok?
        assert File.directory?(File.join(@tmpdir, "a", "b", "c"))
        assert_equal "nested", File.read(path)
      end

      def test_write_returns_bytes_written
        path = File.join(@tmpdir, "test.txt")
        result = @tool.call(path: path, content: "12345")
        assert_predicate result, :ok?
        assert_equal 5, result.output[:bytes]
      end

      def test_write_large_content_rejected
        path = File.join(@tmpdir, "large.txt")
        content = "x" * 600_000
        result = @tool.call(path: path, content: content)
        refute_predicate result, :ok?
        assert_match(/too large/i, result.error)
      end

      def test_missing_path_param
        result = @tool.call({})
        refute_predicate result, :ok?
        assert_match(/missing required parameter/, result.error)
      end
    end
  end
end
