# frozen_string_literal: true

require_relative "../../../test_helper"
require "tmpdir"

module Ask
  module Tools
    # The git tools: scoped git operations run through the sandbox in
    # the session's workspace — status, diff, log, commit, branch,
    # worktree. Every test runs against a real git repository, exactly
    # as a host session would.
    class GitTest < Minitest::Test
      def setup
        @workdir = Dir.mktmpdir("ask-git-tools")
        git("init", "-b", "main")
        git("config", "user.email", "ciro@myrr.test")
        git("config", "user.name", "ciro")
        File.write(File.join(@workdir, "hello.rb"), "puts :hello\n")
        git("add", "hello.rb")
        git("commit", "-m", "Initial commit")
      end

      def teardown
        FileUtils.remove_entry(@workdir)
      end

      def git(*args)
        system("git", "-C", @workdir, *args, exception: true)
      end

      def tool(klass)
        Git.const_get(klass).new.tap { |t| t.default_workdir = @workdir }
      end

      def test_tool_names
        assert_equal "git_status", Git::Status.new.name
        assert_equal "git_diff", Git::Diff.new.name
        assert_equal "git_log", Git::Log.new.name
        assert_equal "git_commit", Git::Commit.new.name
        assert_equal "git_branch", Git::Branch.new.name
        assert_equal "git_worktree", Git::Worktree.new.name
      end

      def test_status_shows_branch_and_clean_tree
        result = tool(:Status).call({})

        assert_predicate result, :ok?
        assert_includes result.output[:stdout], "main"
      end

      def test_status_shows_modified_file
        File.write(File.join(@workdir, "hello.rb"), "puts :goodbye\n")
        result = tool(:Status).call({})

        assert_predicate result, :ok?
        assert_includes result.output[:stdout], "hello.rb"
      end

      def test_diff_shows_unstaged_change
        File.write(File.join(@workdir, "hello.rb"), "puts :goodbye\n")
        result = tool(:Diff).call({})

        assert_predicate result, :ok?
        assert_includes result.output[:stdout], "-puts :hello"
        assert_includes result.output[:stdout], "+puts :goodbye"
      end

      def test_diff_cached_shows_staged_change
        File.write(File.join(@workdir, "hello.rb"), "puts :goodbye\n")
        git("add", "hello.rb")
        result = tool(:Diff).call(cached: true)

        assert_predicate result, :ok?
        assert_includes result.output[:stdout], "+puts :goodbye"
      end

      def test_diff_limited_to_path_only_shows_that_path
        File.write(File.join(@workdir, "other.rb"), "x\n")
        git("add", "other.rb")
        git("commit", "-m", "Add other")
        File.write(File.join(@workdir, "other.rb"), "y\n")
        File.write(File.join(@workdir, "hello.rb"), "puts :goodbye\n")

        result = tool(:Diff).call(path: "other.rb")

        assert_predicate result, :ok?
        assert_includes result.output[:stdout], "other.rb"
        refute_includes result.output[:stdout], "goodbye"
      end

      def test_log_shows_recent_commits
        result = tool(:Log).call({})

        assert_predicate result, :ok?
        assert_includes result.output[:stdout], "Initial commit"
      end

      def test_log_respects_count
        git("commit", "--allow-empty", "-m", "Second commit")
        result = tool(:Log).call(count: 1)

        assert_predicate result, :ok?
        assert_includes result.output[:stdout], "Second commit"
        refute_includes result.output[:stdout], "Initial commit"
      end

      def test_commit_makes_staged_change_history
        File.write(File.join(@workdir, "hello.rb"), "puts :goodbye\n")
        git("add", "hello.rb")

        result = tool(:Commit).call(message: "Say goodbye")

        assert_predicate result, :ok?

        log = tool(:Log).call({})

        assert_includes log.output[:stdout], "Say goodbye"
      end

      def test_commit_refuses_without_message
        result = tool(:Commit).call({})

        refute_predicate result, :ok?
      end

      def test_branch_lists_current_branch
        result = tool(:Branch).call({})

        assert_predicate result, :ok?
        assert_includes result.output[:stdout], "* main"
      end

      def test_worktree_lists_main_worktree
        result = tool(:Worktree).call({})

        assert_predicate result, :ok?
        assert_includes result.output[:stdout], @workdir
      end

      def test_tools_refuse_without_workspace
        result = Git::Status.new.call({})

        refute_predicate result, :ok?
        assert_match(/workspace/, result.error_message)
      end

      def test_tools_report_non_repo_cleanly
        empty = Dir.mktmpdir("ask-git-nonrepo")
        begin
          tool = Git::Status.new.tap { |t| t.default_workdir = empty }
          result = tool.call({})

          refute_predicate result, :ok?
          assert_match(/not a git repository/, result.error_message)
        ensure
          FileUtils.remove_entry(empty)
        end
      end
    end
  end
end
