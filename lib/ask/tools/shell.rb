# frozen_string_literal: true

require_relative "shell/version"
require "ask/tools"
require_relative "shell/bash"
require_relative "shell/read"
require_relative "shell/file_ledger"
require_relative "shell/write"
require_relative "shell/edit"
require_relative "shell/glob"
require_relative "shell/grep"
require_relative "shell/code"
require_relative "shell/apply_patch"
require_relative "shell/repl"
require_relative "shell/git/base"
require_relative "shell/git/status"
require_relative "shell/git/diff"
require_relative "shell/git/log"
require_relative "shell/git/commit"
require_relative "shell/git/branch"
require_relative "shell/git/worktree"

module Ask
  module Tools
    module Shell
      TOOLS = [Bash, Read, Write, Edit, Glob, Grep, Code, ApplyPatch, Repl,
        Git::Status, Git::Diff, Git::Log, Git::Commit, Git::Branch, Git::Worktree].freeze

      def self.all
        TOOLS.map(&:new)
      end
    end
  end
end

# The git tools resolve by name from the global registry (the host's
# name-based fallback for non-built-in tools) — registering here makes
# them available to any host that loads ask-tools-shell.
Ask::Tools.register(Ask::Tools::Git::Status)
Ask::Tools.register(Ask::Tools::Git::Diff)
Ask::Tools.register(Ask::Tools::Git::Log)
Ask::Tools.register(Ask::Tools::Git::Commit)
Ask::Tools.register(Ask::Tools::Git::Branch)
Ask::Tools.register(Ask::Tools::Git::Worktree)
