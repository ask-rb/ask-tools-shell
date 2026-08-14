# frozen_string_literal: true

module Ask
  module Tools
    module Git
      # The working tree's state: current branch plus staged, unstaged,
      # and untracked changes — what the workspace looks like since the
      # last commit. The executor's first question before touching code.
      class Status < Base
        description "Show the git working tree status: current branch and changed files " \
                     "(staged, unstaged, untracked). Read-only."
        name "git_status"

        def execute
          git("status", "--short", "--branch")
        end
      end
    end
  end
end
