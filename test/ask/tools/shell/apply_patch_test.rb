# frozen_string_literal: true

require_relative "../../../test_helper"
require "tmpdir"

module Ask
  module Tools
    class ApplyPatchTest < Minitest::Test
      def setup
        @tool = ApplyPatch.new
        @tmpdir = Dir.mktmpdir("apply_patch_test")
      end

      def teardown
        FileUtils.remove_entry(@tmpdir)
      end

      def test_tool_name
        assert_equal "apply_patch", @tool.name
      end

      def test_add_file
        path = File.join(@tmpdir, "new_file.txt")
        patch = "*** Begin Patch\n*** Add File: #{path}\n+hello world\n+second line\n*** End Patch"
        result = @tool.execute(patchText: patch)
        assert_predicate result, :ok?
        assert File.exist?(path)
        assert_equal "hello world\nsecond line\n", File.read(path)
      end

      def test_add_file_without_plus_prefix
        path = File.join(@tmpdir, "no_prefix.txt")
        patch = "*** Begin Patch\n*** Add File: #{path}\nline without plus\n*** End Patch"
        result = @tool.execute(patchText: patch)
        assert_predicate result, :ok?
        assert_equal "\n", File.read(path)
      end

      def test_add_file_already_exists
        path = File.join(@tmpdir, "existing.txt")
        File.write(path, "content")
        patch = "*** Begin Patch\n*** Add File: #{path}\n+new content\n*** End Patch"
        result = @tool.execute(patchText: patch)
        refute_predicate result, :ok?
        assert_match(/already exists/i, result.error)
      end

      def test_update_file
        path = File.join(@tmpdir, "update.txt")
        File.write(path, "hello world\nfoo bar\nbaz qux")
        patch = "*** Begin Patch\n*** Update File: #{path}\n@@\n-hello world\n+hello there\n foo bar\n*** End Patch"
        result = @tool.execute(patchText: patch)
        assert_predicate result, :ok?
        assert_equal "hello there\nfoo bar\nbaz qux", File.read(path)
      end

      def test_update_file_not_found
        path = File.join(@tmpdir, "nonexistent.txt")
        patch = "*** Begin Patch\n*** Update File: #{path}\n@@\n-old\n+new\n*** End Patch"
        result = @tool.execute(patchText: patch)
        refute_predicate result, :ok?
        assert_match(/does not exist/i, result.error)
      end

      def test_delete_file
        path = File.join(@tmpdir, "delete_me.txt")
        File.write(path, "to be deleted")
        patch = "*** Begin Patch\n*** Delete File: #{path}\n*** End Patch"
        result = @tool.execute(patchText: patch)
        assert_predicate result, :ok?
        refute File.exist?(path)
      end

      def test_delete_file_not_found
        path = File.join(@tmpdir, "ghost.txt")
        patch = "*** Begin Patch\n*** Delete File: #{path}\n*** End Patch"
        result = @tool.execute(patchText: patch)
        refute_predicate result, :ok?
        assert_match(/does not exist/i, result.error)
      end

      def test_empty_patch
        result = @tool.execute(patchText: "")
        refute_predicate result, :ok?
        assert_match(/no valid patch/i, result.error)
      end

      def test_patch_without_envelope
        result = @tool.execute(patchText: "just some text")
        refute_predicate result, :ok?
        assert_match(/no valid patch/i, result.error)
      end

      def test_summary_includes_capitalized_actions
        path = File.join(@tmpdir, "summary_test.txt")
        patch = "*** Begin Patch\n*** Add File: #{path}\n+content\n*** End Patch"
        result = @tool.execute(patchText: patch)
        assert_predicate result, :ok?
        summary = result.output[:summary]
        assert_match(/^Add /, summary)
      end

      def test_multiple_sections_in_one_patch
        f1 = File.join(@tmpdir, "first.txt")
        f2 = File.join(@tmpdir, "second.txt")
        patch = "*** Begin Patch\n*** Add File: #{f1}\n+file one\n*** Add File: #{f2}\n+file two\n*** End Patch"
        result = @tool.execute(patchText: patch)
        assert_predicate result, :ok?
        assert File.exist?(f1)
        assert File.exist?(f2)
        assert_equal 2, result.output[:results].size
      end

      def test_missing_patchText_param
        result = @tool.call({})
        refute_predicate result, :ok?
        assert_match(/missing required parameter/, result.error)
      end

      def test_add_and_update_in_same_patch
        add_path = File.join(@tmpdir, "to_update.txt")
        File.write(add_path, "original")
        patch = "*** Begin Patch\n*** Update File: #{add_path}\n@@\n-original\n+modified\n*** End Patch"
        result = @tool.execute(patchText: patch)
        assert_predicate result, :ok?
        assert_equal "modified", File.read(add_path)
      end

      def test_action_in_summary_is_capitalized_not_upcase_first
        path = File.join(@tmpdir, "cap_test.txt")
        patch = "*** Begin Patch\n*** Add File: #{path}\n+content\n*** End Patch"
        result = @tool.execute(patchText: patch)
        assert_predicate result, :ok?
        action = result.output[:results].first[:action]
        assert_equal "add", action
        assert_equal "Add ", result.output[:summary][0, 4]
      end
    end
  end
end
