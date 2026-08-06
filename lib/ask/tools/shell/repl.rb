# frozen_string_literal: true

require "json"
require "monitor"
require "io/wait"

module Ask
  module Tools
    # Evaluate Ruby code in a persistent, long-lived subprocess.
    #
    # Unlike {Code} (which spawns a fresh `ruby -e` per call), Repl keeps a
    # kernel process alive across calls and evaluates every snippet into the
    # same binding — so state (locals, requires, defined methods) survives
    # between calls. This is the RLM (recursive language model) pattern: the
    # model composes capabilities as code against a persistent environment.
    #
    # @example
    #   repl = Ask::Tools::Repl.new
    #   repl.call(code: 'require "json"; data = JSON.parse(%q({"a": 1}))')
    #   repl.call(code: "data['a'] + 1")       # => 2 — `data` still exists
    #   repl.call(code: "def double(x); x * 2; end")
    #   repl.call(code: "double(21)")          # => 42
    #
    # Sessions are named and shared process-wide: calling with the same
    # +session+ name from any tool instance reaches the same kernel. A
    # session is closed by +reset: true+, {Repl.close_session}, or after
    # {Repl.idle_timeout} seconds without use.
    #
    # @note The kernel runs with the caller's permissions (like {Code}).
    #   It is a durable control environment, not a security sandbox.
    class Repl < Ask::Tool
      description "Evaluate Ruby code in a persistent session. " \
                   "State (variables, requires, defined methods) survives " \
                   "across calls in the same session. " \
                   "Use sessions to keep working context alive."

      param :code, type: :string, desc: "Ruby source code to evaluate", required: true
      param :session, type: :string, desc: "Session name; state persists per name", required: false
      param :reset, type: :boolean, desc: "Discard session state before evaluating", required: false

      # Timeout for a single evaluation, in seconds.
      DEFAULT_EVAL_TIMEOUT = 30

      # Sessions idle longer than this are closed on next access.
      DEFAULT_IDLE_TIMEOUT = 300

      # Env vars that would drag the parent's bundler context into the
      # kernel subprocess (RUBYOPT=-rbundler/setup restricts $LOAD_PATH to
      # the parent's Gemfile). Nil overrides remove them at spawn so the
      # session is plain ruby, like the one-shot Code tool's sandbox.
      BUNDLER_ENV = %w[
        RUBYOPT RUBYLIB BASH_ENV GEM_PATH GEM_HOME
        BUNDLE_GEMFILE BUNDLE_PATH BUNDLE_BIN_PATH BUNDLER_SETUP
        BUNDLER_VERSION BUNDLE_WITHOUT BUNDLE_FROZEN BUNDLE_DEPLOYMENT
        BUNDLE_LOCKFILE BUNDLE_APP_CONFIG
      ].freeze

      class << self
        # @return [Integer] seconds a session may sit unused before it is
        #   closed on next access
        attr_accessor :idle_timeout

        # @return [Integer] seconds a single evaluation may take
        attr_accessor :eval_timeout
      end

      self.idle_timeout = DEFAULT_IDLE_TIMEOUT
      self.eval_timeout = DEFAULT_EVAL_TIMEOUT

      @registry = {}
      @registry_mutex = Monitor.new

      class << self
        # The kernel for +session+, spawning one if needed (or after reset).
        #
        # @param session [String]
        # @param reset [Boolean] discard existing session state
        # @return [Kernel]
        def kernel_for(session, reset: false)
          @registry_mutex.synchronize do
            close_session(session) if reset
            kernel = @registry[session]
            if kernel.nil? || kernel.dead?
              kernel = Kernel.new(session: session)
              @registry[session] = kernel
            elsif kernel.idle_seconds > idle_timeout
              kernel.close
              kernel = Kernel.new(session: session)
              @registry[session] = kernel
            end
            kernel
          end
        end

        # Close and forget a session's kernel.
        #
        # @param session [String]
        # @return [void]
        def close_session(session)
          @registry_mutex.synchronize do
            kernel = @registry.delete(session)
            kernel&.close
          end
          nil
        end

        # Close every session kernel. Called at exit; call it explicitly to
        # free subprocesses early.
        #
        # @return [void]
        def close_all
          @registry_mutex.synchronize do
            @registry.each_value(&:close)
            @registry.clear
          end
          nil
        end

        # @return [Array<String>] active session names
        def sessions
          @registry_mutex.synchronize { @registry.keys }
        end
      end

      at_exit { Repl.close_all }

      def execute(code:, session: "default", reset: false)
        build_result(eval_code(session, code, reset: reset), session)
      rescue Kernel::TimeoutError => e
        Ask::Result.error(message: "REPL session '#{session}' timed out (#{e.timeout}s); session state was lost")
      rescue Kernel::DeadError => e
        # The session died (crash, external kill, closed stdin). Respawn a
        # fresh kernel and retry once; only give up if it dies again.
        begin
          build_result(eval_code(session, code), session)
        rescue Kernel::DeadError
          Ask::Result.error(message: "REPL session '#{session}' died repeatedly: #{e.message}")
        end
      end

      private

      def eval_code(session, code, reset: false)
        Repl.kernel_for(session, reset: reset).eval(code, timeout: Repl.eval_timeout)
      end

      def build_result(result, session)
        if result["error"]
          Ask::Result.error(
            message: result["error"],
            metadata: { session: session, stdout: result["stdout"], stderr: result["stderr"] }
          )
        else
          Ask::Result.ok(data: {
            result: result["result"],
            stdout: result["stdout"],
            stderr: result["stderr"],
            session: session
          })
        end
      end

      # A single long-lived Ruby subprocess executing the kernel script.
      #
      # Communicates over newline-delimited JSON on stdin/stdout. One eval
      # at a time per kernel; concurrent calls serialize on an internal
      # monitor.
      class Kernel
        class Error < StandardError; end
        class TimeoutError < Error
          attr_reader :timeout

          def initialize(timeout)
            @timeout = timeout
            super("evaluation exceeded #{timeout}s")
          end
        end
        class DeadError < Error; end

        # @return [String] session name this kernel belongs to
        attr_reader :session

        # @return [Time] last time an evaluation completed
        attr_reader :last_used

        def initialize(session:, ruby: "ruby")
          @session = session
          @script = File.expand_path("repl/kernel_script.rb", __dir__)
          @monitor = Monitor.new
          @last_used = Time.now
          @next_id = 0
          spawn_process(ruby)
        end

        # @return [Float] seconds since the last evaluation
        def idle_seconds
          Time.now - @last_used
        end

        # @return [Boolean] whether the kernel process is gone. Reaps the
        #   child if it already exited (zombies count as dead).
        def dead?
          return true if @closed
          return true unless @pid

          _, status = Process.waitpid(@pid, Process::WNOHANG)
          if status.nil?
            false
          else
            @pid = nil
            true
          end
        rescue Errno::ECHILD, Errno::ESRCH, Errno::EINTR
          @pid = nil
          true
        end

        # Evaluate +code+ in the persistent binding.
        #
        # @param code [String]
        # @param timeout [Integer] max seconds for this evaluation
        # @return [Hash] {"result" => String, "stdout" => String,
        #   "stderr" => String, "error" => String or nil}
        # @raise [TimeoutError] evaluation exceeded +timeout+; the kernel
        #   was killed and session state lost
        # @raise [DeadError] the kernel process died
        def eval(code, timeout: Repl.eval_timeout)
          @monitor.synchronize do
            raise DeadError, "process not running" if dead?

            id = (@next_id += 1)
            write_frame("id" => id, "code" => code)
            response = read_frame(id, timeout)
            @last_used = Time.now
            response
          end
        end

        # Terminate the kernel process and close pipes. TERM is normally
        # enough (the kernel script exits on it); KILL is the fallback for
        # user code that overrode the trap or wedged the VM.
        #
        # @return [void]
        def close
          @monitor.synchronize do
            return if @closed

            @closed = true
            if @pid
              begin
                Process.kill("TERM", @pid)
              rescue Errno::ESRCH, Errno::ECHILD
                @pid = nil
              end
              wait_for_exit(2)
              if @pid
                begin
                  Process.kill("KILL", @pid)
                rescue Errno::ESRCH, Errno::ECHILD
                  @pid = nil
                end
                wait_for_exit(1)
              end
            end
            @in_w.close unless @in_w.closed?
            @out_r.close unless @out_r.closed?
            @err_r.close unless @err_r.closed?
          end
          nil
        end

        private

        # Poll until the child exits or +seconds+ elapse. Reaps the child
        # when it does. Avoids blocking +Process.wait+ which Timeout cannot
        # always interrupt.
        #
        # @param seconds [Numeric]
        # @return [void]
        def wait_for_exit(seconds)
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
          loop do
            _, status = Process.waitpid(@pid, Process::WNOHANG)
            return if status

            break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

            sleep 0.01
          end
        rescue Errno::ECHILD, Errno::ESRCH, Errno::EINTR
          @pid = nil
        end

        def spawn_process(ruby)
          @in_r, @in_w = IO.pipe
          @out_r, @out_w = IO.pipe
          @err_r, @err_w = IO.pipe

          # The kernel is a plain ruby environment: remove bundler plumbing
          # inherited from the parent (RUBYOPT=-rbundler/setup etc.) so the
          # session sees globally installed gems, not the parent's Gemfile
          # subset. Note: Process.spawn *merges* its env hash with the
          # parent environment — only explicit nil values delete keys.
          env = BUNDLER_ENV.to_h { |key| [key, nil] }

          @pid = Process.spawn(
            env, ruby, @script,
            in: @in_r, out: @out_w, err: @err_w
          )
          @in_r.close
          @out_w.close
          @err_w.close
        rescue StandardError
          close
          raise
        end

        def write_frame(frame)
          @in_w.write(JSON.generate(frame) + "\n")
          @in_w.flush
        rescue Errno::EPIPE, IOError => e
          raise DeadError, e.message
        end

        def read_frame(expected_id, timeout)
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

          loop do
            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
            if remaining <= 0
              close
              raise TimeoutError, timeout
            end

            ready = @out_r.wait_readable(remaining)
            unless ready
              close
              raise TimeoutError, timeout
            end

            line = @out_r.gets
            if line.nil?
              err = @err_r.read
              close
              raise DeadError, "kernel exited unexpectedly#{err.empty? ? "" : ": #{err.strip}"}"
            end

            frame = JSON.parse(line)
            return frame if frame["id"] == expected_id
          rescue JSON::ParserError
            next
          end
        end
      end
    end
  end
end
