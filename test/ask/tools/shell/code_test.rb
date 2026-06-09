# frozen_string_literal: true

require_relative "../../../test_helper"

module Ask
  module Tools
    class CodeTest < Minitest::Test
      def setup
        @tool = Code.new
      end

      def test_tool_name
        assert_equal "code", @tool.name
      end

      def test_execute_ruby_code
        result = @tool.call(code: "puts 'hello from ruby'")
        assert_predicate result, :ok?
        assert_match(/hello from ruby/, result.output[:stdout])
        assert_equal 0, result.output[:exit_code]
      end

      def test_execute_with_return_value
        result = @tool.call(code: "puts 2 + 2")
        assert_predicate result, :ok?
        assert_match(/4/, result.output[:stdout])
      end

      def test_execute_with_stderr
        result = @tool.call(code: "warn 'warning message'")
        assert_predicate result, :ok?
        assert_match(/warning message/, result.output[:stderr])
      end

      def test_execute_with_error
        result = @tool.call(code: "raise 'boom'")
        assert_predicate result, :ok?
        assert_equal 1, result.output[:exit_code]
        assert_match(/boom/, result.output[:stderr])
      end

      def test_missing_code_param
        result = @tool.call({})
        refute_predicate result, :ok?
        assert_match(/missing required parameter/, result.error)
      end
    end
  end
end
