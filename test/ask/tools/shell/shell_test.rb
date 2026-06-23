# frozen_string_literal: true

require_relative "../../../test_helper"

module Ask
  module Tools
    class ShellTest < Minitest::Test
      def test_shell_all_returns_all_8_tool_instances
        instances = Shell.all
        assert_equal 8, instances.size
      end

      def test_shell_all_returns_tool_instances
        Shell.all.each do |instance|
          assert_kind_of Ask::Tool, instance
          assert_respond_to instance, :call
          assert_respond_to instance, :name
        end
      end

      def test_shell_all_includes_bash
        names = Shell.all.map(&:name)
        assert_includes names, "bash"
      end

      def test_shell_all_includes_read
        names = Shell.all.map(&:name)
        assert_includes names, "read"
      end

      def test_shell_all_includes_write
        names = Shell.all.map(&:name)
        assert_includes names, "write"
      end

      def test_shell_all_includes_edit
        names = Shell.all.map(&:name)
        assert_includes names, "edit"
      end

      def test_shell_all_includes_glob
        names = Shell.all.map(&:name)
        assert_includes names, "glob"
      end

      def test_shell_all_includes_grep
        names = Shell.all.map(&:name)
        assert_includes names, "grep"
      end

      def test_shell_all_includes_code
        names = Shell.all.map(&:name)
        assert_includes names, "code"
      end

      def test_shell_all_includes_apply_patch
        names = Shell.all.map(&:name)
        assert_includes names, "apply_patch"
      end
    end
  end
end
