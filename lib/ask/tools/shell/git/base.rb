# frozen_string_literal: true

require "ask-sandbox-providers"

module Ask
  module Tools
    module Git
      # Shared plumbing for the git tools: run scoped git commands in
      # the workspace through the sandbox — the same provider bash
      # uses, but with a fixed command (never a free-form shell) and
      # argv-array form (nothing passes through a shell, so a hostile
      # value stays a value).
      #
      # The host pins default_workdir to the session's workspace (the
      # same mechanism Bash's workdir uses); a tool invoked without a
      # workspace — outside a session — refuses loudly rather than
      # touching the host's own checkout.
      class Base < Ask::Tool
        # The session's workspace: set by the host when it builds the
        # session's tools.
        attr_accessor :default_workdir

        private

        # Run git with the given arguments in the workspace and map
        # the sandbox result to Ask::Result, the ecosystem convention.
        def git(*args, timeout: 30)
          if default_workdir.to_s.empty?
            return Ask::Result.error(message: "git tools need a session workspace")
          end

          result = Ask::Sandbox.provider.call(["git", *args], timeout: timeout, workdir: default_workdir)
          data = {stdout: result.stdout, stderr: result.stderr, exit_code: result.exit_code, timed_out: result.timed_out}
          if result.success?
            Ask::Result.ok(data: data)
          else
            stderr = result.stderr.to_s.strip
            Ask::Result.error(message: stderr.empty? ? "git failed" : stderr, metadata: data)
          end
        end
      end
    end
  end
end
