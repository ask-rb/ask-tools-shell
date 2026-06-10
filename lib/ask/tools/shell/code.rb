# frozen_string_literal: true

require "ask-sandbox-providers"

module Ask
  module Tools
    # Write and execute Ruby code in a subprocess.
    # Runs via Ask::Sandbox.provider (Local by default, configurable for
    # stronger isolation via Docker, Daytona, or Cloudflare).
    class Code < Ask::Tool
      description "Write and execute Ruby code in a subprocess. " \
                   "Returns stdout, stderr, and exit code. " \
                   "Uses gems already available in the environment."

      param :code, type: :string, desc: "Ruby source code to execute", required: true

      def execute(code:)
        result = Ask::Sandbox.provider.call(
          ["ruby", "-e", code],
          timeout: 30
        )

        if result.timed_out
          return Ask::Result.error(
            message: "Code execution timed out",
            metadata: { stdout: result.stdout, stderr: result.stderr }
          )
        end

        Ask::Result.ok(data: {
          stdout: result.stdout,
          stderr: result.stderr,
          exit_code: result.exit_code
        })
      end
    end
  end
end
