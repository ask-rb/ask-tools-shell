# frozen_string_literal: true

require_relative "../../../test_helper"

module Ask
  module Tools
    class ReplTest < Minitest::Test
      SESSION = "repl_test"

      def setup
        @tool = Repl.new
        Repl.close_session(SESSION)
      end

      def teardown
        Repl.close_session(SESSION)
      end

      def test_tool_name
        assert_equal "repl", @tool.name
      end

      def test_description_mentions_persistence
        assert_match(/persistent/, Repl.description)
      end

      def test_missing_code_param
        result = @tool.call({})
        refute_predicate result, :ok?
        assert_match(/missing required parameter/, result.error)
      end

      def test_evaluates_code
        result = @tool.call(code: "1 + 1", session: SESSION)
        assert_predicate result, :ok?
        assert_equal "2", result.output[:result]
      end

      def test_state_persists_across_calls
        @tool.call(code: "x = 41", session: SESSION)
        result = @tool.call(code: "x + 1", session: SESSION)
        assert_predicate result, :ok?
        assert_equal "42", result.output[:result]
      end

      def test_stdout_and_stderr_captured
        result = @tool.call(code: "puts 'out here'; warn 'err here'", session: SESSION)
        assert_predicate result, :ok?
        assert_match(/out here/, result.output[:stdout])
        assert_match(/err here/, result.output[:stderr])
      end

      def test_stdout_does_not_leak_between_evals
        @tool.call(code: "puts 'first'", session: SESSION)
        result = @tool.call(code: "puts 'second'", session: SESSION)
        assert_predicate result, :ok?
        refute_match(/first/, result.output[:stdout])
        assert_match(/second/, result.output[:stdout])
      end

      def test_requires_persist
        @tool.call(code: 'require "json"', session: SESSION)
        result = @tool.call(code: 'JSON.parse(%q({"a": 1}))["a"]', session: SESSION)
        assert_predicate result, :ok?
        assert_equal "1", result.output[:result]
      end

      def test_bundled_gems_loadable
        # Under `bundle exec`, RUBYOPT=-rbundler/setup restricts $LOAD_PATH
        # to the Gemfile; the kernel must be plain ruby so globally
        # installed gems (csv is a bundled gem since Ruby 3.4) load.
        result = @tool.call(code: 'require "csv"; CSV.generate { |c| c << [1, 2] }', session: SESSION)
        assert_predicate result, :ok?
        assert_equal '"1,2\n"', result.output[:result]
      end

      def test_defined_methods_persist
        @tool.call(code: "def triple(n); n * 3; end", session: SESSION)
        result = @tool.call(code: "triple(14)", session: SESSION)
        assert_predicate result, :ok?
        assert_equal "42", result.output[:result]
      end

      def test_rescue_in_kernel_reports_error_not_crash
        result = @tool.call(code: "raise 'boom'", session: SESSION)
        refute_predicate result, :ok?
        assert_match(/boom/, result.error)
      end

      def test_session_state_survives_an_error
        @tool.call(code: "y = 40", session: SESSION)
        @tool.call(code: "raise 'boom'", session: SESSION)
        result = @tool.call(code: "y + 2", session: SESSION)
        assert_predicate result, :ok?
        assert_equal "42", result.output[:result]
      end

      def test_sessions_are_isolated
        @tool.call(code: "z = 1", session: "#{SESSION}_a")
        result = @tool.call(code: "defined?(z) || 'gone'", session: "#{SESSION}_b")
        assert_predicate result, :ok?
        assert_equal '"gone"', result.output[:result] # inspect of String
      ensure
        Repl.close_session("#{SESSION}_a")
        Repl.close_session("#{SESSION}_b")
      end

      def test_reset_discards_state
        @tool.call(code: "w = 99", session: SESSION)
        result = @tool.call(code: "defined?(w) || 'gone'", session: SESSION, reset: true)
        assert_predicate result, :ok?
        assert_equal '"gone"', result.output[:result]
      end

      def test_result_includes_session_name
        result = @tool.call(code: "1", session: SESSION)
        assert_equal SESSION, result.output[:session]
      end

      def test_failed_eval_includes_session_metadata
        result = @tool.call(code: "raise ArgumentError, 'nope'", session: SESSION)
        refute_predicate result, :ok?
        assert_equal SESSION, result.metadata[:session]
      end

      def test_parallel_calls_to_same_session_serialize
        threads = 4.times.map do |i|
          Thread.new { @tool.call(code: "sleep 0.05; #{i} * 2", session: SESSION) }
        end
        results = threads.map(&:value)
        assert results.all?(&:ok?)
        assert_equal %w[0 2 4 6], results.map { |r| r.output[:result] }.sort
      end

      def test_kernel_reports_dead_session
        kernel = Repl.kernel_for(SESSION)
        Process.kill("KILL", kernel.instance_variable_get(:@pid))
        sleep 0.05
        result = @tool.call(code: "1", session: SESSION)
        assert_predicate result, :ok? # respawns transparently
        assert_equal "1", result.output[:result]
      end

      def test_close_all_terminates_processes
        Repl.kernel_for(SESSION)
        pid = Repl.kernel_for(SESSION).instance_variable_get(:@pid)
        Repl.close_all
        assert_raises(Errno::ESRCH) { Process.kill(0, pid) }
      end

      def test_eval_timeout_returns_error_and_kills_session
        old = Repl.eval_timeout
        Repl.eval_timeout = 1
        @tool.call(code: "x = 1", session: SESSION)
        result = @tool.call(code: "sleep 30", session: SESSION)
        refute_predicate result, :ok?
        assert_match(/timed out/, result.error)
        assert_match(/state was lost/, result.error)
      ensure
        Repl.eval_timeout = old
      end

      def test_session_recovers_after_timeout
        old = Repl.eval_timeout
        Repl.eval_timeout = 1
        @tool.call(code: "v = 41", session: SESSION)
        @tool.call(code: "sleep 30", session: SESSION)
        result = @tool.call(code: "defined?(v) || 'fresh'", session: SESSION)
        assert_predicate result, :ok?
        assert_equal '"fresh"', result.output[:result]
      ensure
        Repl.eval_timeout = old
      end

      def test_idle_sessions_are_recycled
        old = Repl.idle_timeout
        Repl.idle_timeout = 0
        kernel = Repl.kernel_for(SESSION)
        pid = kernel.instance_variable_get(:@pid)
        kernel.instance_variable_set(:@last_used, Time.now - 5)
        new_kernel = Repl.kernel_for(SESSION)
        refute_equal pid, new_kernel.instance_variable_get(:@pid)
      ensure
        Repl.idle_timeout = old
        Repl.close_session(SESSION)
      end
    end
  end
end
