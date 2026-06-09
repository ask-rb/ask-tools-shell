# frozen_string_literal: true

require_relative "../../../test_helper"
require "tmpdir"

module Ask
  module Tools
    class GlobTest < Minitest::Test
      def setup
        @tool = Glob.new
        @tmpdir = Dir.mktmpdir("glob_test")
        File.write(File.join(@tmpdir, "a.rb"), "a")
        File.write(File.join(@tmpdir, "b.rb"), "b")
        File.write(File.join(@tmpdir, "c.txt"), "c")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir)
      end

      def test_tool_name
        assert_equal "glob", @tool.name
      end

      def test_glob_ruby_files
        result = @tool.call(pattern: "*.rb", path: @tmpdir)
        assert_predicate result, :ok?
        assert_match(/a\.rb/, result.output)
        assert_match(/b\.rb/, result.output)
        refute_match(/c\.txt/, result.output)
      end

      def test_glob_all_files
        result = @tool.call(pattern: "*", path: @tmpdir)
        assert_predicate result, :ok?
        assert_match(/a\.rb/, result.output)
        assert_match(/c\.txt/, result.output)
      end

      def test_glob_nonexistent_dir
        result = @tool.call(pattern: "*.rb", path: "/tmp/nonexistent_glob_dir")
        refute_predicate result, :ok?
        assert_match(/does not exist/i, result.error)
      end

      def test_glob_no_matches
        result = @tool.call(pattern: "*.md", path: @tmpdir)
        refute_predicate result, :ok?
        assert_match(/no files found/i, result.error)
      end

      def test_missing_pattern
        result = @tool.call({})
        refute_predicate result, :ok?
        assert_match(/missing required parameter/, result.error)
      end
    end
  end
end
