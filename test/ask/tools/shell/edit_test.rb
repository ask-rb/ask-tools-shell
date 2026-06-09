# frozen_string_literal: true

require_relative "../../../test_helper"
require "tempfile"

module Ask
  module Tools
    class EditTest < Minitest::Test
      def setup
        @tool = Edit.new
        @tmpfile = Tempfile.new(["edit_test", ".txt"])
        @tmpfile.write("hello world\nfoo bar\nhello world")
        @tmpfile.close
      end

      def teardown
        @tmpfile.unlink
      end

      def test_tool_name
        assert_equal "edit", @tool.name
      end

      def test_replace_string
        result = @tool.call(path: @tmpfile.path, old_string: "hello", new_string: "hi")
        assert_predicate result, :ok?
        content = File.read(@tmpfile.path)
        assert_match(/^hi world/, content)
        assert_match(/hello world$/, content) # only first occurrence replaced
      end

      def test_replace_all
        result = @tool.call(path: @tmpfile.path, old_string: "hello", new_string: "hi", replace_all: true)
        assert_predicate result, :ok?
        content = File.read(@tmpfile.path)
        assert_equal "hi world\nfoo bar\nhi world", content
      end

      def test_string_not_found
        result = @tool.call(path: @tmpfile.path, old_string: "nonexistent", new_string: "x")
        refute_predicate result, :ok?
        assert_match(/not found/i, result.error)
      end

      def test_file_not_found
        result = @tool.call(path: "/tmp/nonexistent_file_edit", old_string: "x", new_string: "y")
        refute_predicate result, :ok?
        assert_match(/does not exist/i, result.error)
      end

      def test_missing_params
        result = @tool.call({})
        refute_predicate result, :ok?
        assert_match(/missing required parameter/, result.error)
      end
    end
  end
end
