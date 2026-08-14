# frozen_string_literal: true

module Ask
  module Tools
    module Git
      # Commit the staged changes with a message. The one mutation in
      # the git toolkit: the executor's deliverable becomes history.
      # Commits only what is staged — staging stays a deliberate act.
      class Commit < Base
        description "Commit the staged changes in the workspace with the given message. " \
                     "Mutating — only what is staged is committed."
        name "git_commit"

        params do
          string :message, description: "The commit message", required: true
        end

        def execute(message:)
          git("commit", "-m", message)
        end
      end
    end
  end
end
