# frozen_string_literal: true

require_relative "../../../test_helper"

module Ask
  module Tools
    class BashTest < Minitest::Test
      def setup
        @tool = Bash.new
      end

      def test_tool_name
        assert_equal "bash", @tool.name
      end

      def test_execute_echo
        result = @tool.call(command: "echo hello")
        assert_predicate result, :ok?
        assert_match(/hello/, result.output[:stdout])
        assert_equal 0, result.output[:exit_code]
      end

      def test_execute_exit_code
        result = @tool.call(command: "exit 42")
        assert_predicate result, :ok?
        assert_equal 42, result.output[:exit_code]
      end

      def test_execute_stderr
        result = @tool.call(command: "echo error >&2")
        assert_predicate result, :ok?
        assert_match(/error/, result.output[:stderr])
      end

      def test_missing_command_param
        result = @tool.call({})
        refute_predicate result, :ok?
        assert_match(/missing required parameter/, result.error)
      end

      def test_timeout_kills_process
        result = @tool.call(command: "sleep 10", timeout: 1)
        refute_predicate result, :ok?
        assert_match /(Command timed out|Operation not permitted|EPERM)/, result.error
      end
    end
  end
end
