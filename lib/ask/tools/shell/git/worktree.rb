# frozen_string_literal: true

module Ask
  module Tools
    module Git
      # The workspace's worktrees: paths, branches, and checked-out
      # commits — parallel work happening in the same repository.
      # Read-only.
      class Worktree < Base
        description "Show the git worktrees in the workspace: path, branch, and commit. Read-only."
        name "git_worktree"

        def execute
          git("worktree", "list")
        end
      end
    end
  end
end
