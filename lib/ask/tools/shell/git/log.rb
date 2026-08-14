# frozen_string_literal: true

module Ask
  module Tools
    module Git
      # Recent commit history: hash, subject, author, relative time —
      # the executor's sense of where the branch has been. Read-only.
      class Log < Base
        description "Show the recent commit history: hash, subject, author, and relative time. Read-only."
        name "git_log"

        params do
          integer :count, description: "How many commits to show", required: false
        end

        def execute(count: 20)
          git("log", "--oneline", "-n", count.to_s)
        end
      end
    end
  end
end
