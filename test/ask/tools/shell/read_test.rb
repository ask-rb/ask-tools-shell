# frozen_string_literal: true

require_relative "../../../test_helper"
require "tempfile"

module Ask
  module Tools
    class ReadTest < Minitest::Test
      def setup
        @tool = Read.new
        @tmpfile = Tempfile.new(["read_test", ".txt"])
        @tmpfile.write("line one\nline two\nline three\n")
        @tmpfile.close
      end

      def teardown
        @tmpfile.unlink
      end

      def test_tool_name
        assert_equal "read", @tool.name
      end

      def test_read_file
        result = @tool.call(path: @tmpfile.path)
        assert_predicate result, :ok?
        assert_match(/line one/, result.output)
        assert_match(/line two/, result.output)
        assert_match(/line three/, result.output)
      end

      def test_read_with_line_numbers
        result = @tool.call(path: @tmpfile.path)
        assert_predicate result, :ok?
        assert_match(/1: line one/, result.output)
        assert_match(/2: line two/, result.output)
        assert_match(/3: line three/, result.output)
      end

      def test_read_with_offset
        result = @tool.call(path: @tmpfile.path, offset: 1)
        assert_predicate result, :ok?
        refute_match(/1: line one/, result.output)
        assert_match(/2: line two/, result.output)
      end

      def test_read_with_limit
        result = @tool.call(path: @tmpfile.path, limit: 1)
        assert_predicate result, :ok?
        assert_match(/1: line one/, result.output)
        refute_match(/2: line two/, result.output)
      end

      def test_read_nonexistent_path
        result = @tool.call(path: "/tmp/nonexistent_file_12345")
        refute_predicate result, :ok?
        assert_match(/does not exist/i, result.error)
      end

      def test_read_directory
        result = @tool.call(path: Dir.pwd)
        assert_predicate result, :ok?
        assert_kind_of String, result.output
      end

      def test_missing_path_param
        result = @tool.call({})
        refute_predicate result, :ok?
        assert_match(/missing required parameter/, result.error)
      end
    end
  end
end
