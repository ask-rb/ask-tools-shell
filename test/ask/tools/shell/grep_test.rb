# frozen_string_literal: true

require_relative "../../../test_helper"
require "tmpdir"

module Ask
  module Tools
    class GrepTest < Minitest::Test
      def setup
        @tool = Grep.new
        @tmpdir = Dir.mktmpdir("grep_test")
        File.write(File.join(@tmpdir, "hello.rb"), "# hello world\nputs 'hello'\n# goodbye")
        File.write(File.join(@tmpdir, "other.txt"), "no match here")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir)
      end

      def test_tool_name
        assert_equal "grep", @tool.name
      end

      def test_grep_pattern
        result = @tool.call(pattern: "hello", path: @tmpdir)
        assert_predicate result, :ok?
        assert_match(/hello\.rb/, result.output)
        refute_match(/other\.txt/, result.output)
      end

      def test_grep_with_include_filter
        result = @tool.call(pattern: "hello", path: @tmpdir, include: "*.rb")
        assert_predicate result, :ok?
        assert_match(/hello\.rb/, result.output)
        refute_match(/other\.txt/, result.output)
      end

      def test_grep_no_matches
        result = @tool.call(pattern: "zzzzz", path: @tmpdir)
        refute_predicate result, :ok?
        assert_match(/no matches/i, result.error)
      end

      def test_grep_invalid_regex
        result = @tool.call(pattern: "[", path: @tmpdir)
        refute_predicate result, :ok?
        assert_match(/invalid regex/i, result.error)
      end

      def test_grep_pattern_under_system_tmp
        # Regression: exclude-dir matching must be relative to the search
        # root. The old check matched any absolute path containing "/tmp/",
        # so a search rooted under the system tmp dir (the default for
        # Dir.mktmpdir on Linux CI) excluded every file.
        dir = Dir.mktmpdir("grep_tmp_root", "/tmp")
        File.write(File.join(dir, "hello.rb"), "# hello world\n")
        result = @tool.call(pattern: "hello", path: dir)
        assert_predicate result, :ok?
        assert_match(/hello\.rb/, result.output)
      ensure
        FileUtils.remove_entry(dir) if dir
      end

      def test_grep_nonexistent_dir
        result = @tool.call(pattern: "test", path: "/tmp/nonexistent_grep")
        refute_predicate result, :ok?
        assert_match(/does not exist/i, result.error)
      end

      def test_missing_pattern_param
        result = @tool.call({})
        refute_predicate result, :ok?
        assert_match(/missing required parameter/, result.error)
      end
    end
  end
end
