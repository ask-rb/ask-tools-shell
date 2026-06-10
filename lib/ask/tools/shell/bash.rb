# frozen_string_literal: true

require "ask-sandbox-providers"

module Ask
  module Tools
    # Execute shell commands in a sandboxed environment.
    # Runs via Ask::Sandbox.provider (Local by default, configurable for
    # stronger isolation via Docker, Daytona, or Cloudflare).
    class Bash < Ask::Tool
      description "Execute a bash command in a sandboxed environment. " \
                   "Returns stdout, stderr, and exit code. " \
                   "Output is truncated to 100KB."

      param :command, type: :string, desc: "The bash command to execute", required: true
      param :timeout, type: :integer, desc: "Timeout in seconds", required: false
      param :workdir, type: :string, desc: "Working directory", required: false

      def execute(command:, timeout: 30, workdir: nil)
        result = Ask::Sandbox.provider.call(
          command,
          timeout: timeout,
          workdir: workdir
        )

        if result.timed_out
          return Ask::Result.error(
            message: "Command timed out",
            metadata: { stdout: result.stdout, stderr: result.stderr }
          )
        end

        Ask::Result.ok(data: {
          stdout: result.stdout,
          stderr: result.stderr,
          exit_code: result.exit_code,
          timed_out: result.timed_out
        })
      end
    end
  end
end
