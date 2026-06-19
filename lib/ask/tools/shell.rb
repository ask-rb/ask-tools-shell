# frozen_string_literal: true

require_relative "shell/version"
require "ask/tools/tool"
require_relative "shell/bash"
require_relative "shell/read"
require_relative "shell/write"
require_relative "shell/edit"
require_relative "shell/glob"
require_relative "shell/grep"
require_relative "shell/code"

module Ask
  module Tools
    module Shell
      TOOLS = [Bash, Read, Write, Edit, Glob, Grep, Code].freeze
    end
  end
end
