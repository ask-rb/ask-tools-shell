# frozen_string_literal: true

module Ask
  module Tools
    # Collection point for shell tools.
    #
    #   Ask::Tools::Shell.all  # => [Bash, Read, Write, ...] instances
    #
    module Shell
      TOOLS = [Bash, Read, Write, Edit, Glob, Grep, Code].freeze

      # Return an instance of every registered shell tool.
      #
      # @return [Array<Ask::Tool>]
      def self.all
        TOOLS.map(&:new)
      end
    end
  end
end
