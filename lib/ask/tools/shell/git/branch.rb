# frozen_string_literal: true

module Ask
  module Tools
    module Git
      # The workspace's branches: which one is checked out, and what
      # else exists. Read-only.
      class Branch < Base
        description "Show the current branch and all local branches in the workspace. Read-only."
        name "git_branch"

        def execute
          git("branch", "--list")
        end
      end
    end
  end
end
