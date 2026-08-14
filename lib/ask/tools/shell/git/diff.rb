# frozen_string_literal: true

module Ask
  module Tools
    module Git
      # The changes themselves: an unstaged diff by default, staged
      # with `cached`, optionally limited to one path. Read-only —
      # the executor reads before it writes.
      class Diff < Base
        description "Show the uncommitted diff in the workspace: unstaged by default, " \
                     "staged with cached: true, optionally limited to one path. Read-only."
        name "git_diff"

        params do
          boolean :cached, description: "Diff the staged changes instead", required: false
          string :path, description: "Limit the diff to this path", required: false
        end

        def execute(cached: false, path: nil)
          args = ["diff"]
          args << "--cached" if cached
          args += ["--", path] if path
          git(*args)
        end
      end
    end
  end
end
