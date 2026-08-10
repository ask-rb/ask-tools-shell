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

      # ── Partial-view ledger: refuse to destroy what was never seen ──

      def test_write_denied_after_partial_read
        path = File.join(@tmpdir, "plan.md")
        File.write(path, (1..30).map { |i| "line #{i}" }.join("\n"))
        reader = Read.new
        reader.max_lines = 10
        reader.call(path: path)

        result = @tool.call(path: path, content: "overwrite")
        refute_predicate result, :ok?
        assert_match(/part of the file has been read/i, result.error)
        assert_match(/re-read/i, result.error)
        assert_equal((1..30).map { |i| "line #{i}" }.join("\n"), File.read(path)) # untouched
      end

      def test_write_allowed_after_full_read
        path = File.join(@tmpdir, "seen.txt")
        File.write(path, "full content\n")
        Read.new.call(path: path)

        result = @tool.call(path: path, content: "new content")
        assert_predicate result, :ok?
        assert_equal "new content", File.read(path)
      end

      def test_write_allowed_when_file_changed_since_partial_read
        path = File.join(@tmpdir, "changed.txt")
        File.write(path, (1..30).map { |i| "line #{i}" }.join("\n"))
        reader = Read.new
        reader.max_lines = 10
        reader.call(path: path)

        File.write(path, "rewritten by someone else\n")
        result = @tool.call(path: path, content: "mine now")
        assert_predicate result, :ok? # ledger entry stale; the model saw old bytes
      end

      def test_write_allowed_after_edit
        path = File.join(@tmpdir, "edited.txt")
        File.write(path, "hello world\n" + (1..30).map { |i| "line #{i}" }.join("\n"))
        reader = Read.new
        reader.max_lines = 10
        reader.call(path: path)

        Edit.new.call(path: path, old_string: "hello", new_string: "hi")
        result = @tool.call(path: path, content: "clean rewrite")
        assert_predicate result, :ok?
      end
    end
  end
end
