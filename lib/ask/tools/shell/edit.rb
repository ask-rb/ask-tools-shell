# frozen_string_literal: true

module Ask
  module Tools
    # Edit a file by replacing exact text.
    # Uses exact string matching — provide enough surrounding context for uniqueness.
    class Edit < Ask::Tool
      description "Edit a file by replacing exact text. " \
                   "Uses exact string matching — provide enough surrounding context for uniqueness."

      param :path, type: :string, desc: "Absolute path to the file", required: true
      param :old_string, type: :string, desc: "Exact text to replace", required: true
      param :new_string, type: :string, desc: "Replacement text", required: true
      param :replace_all, type: :boolean, desc: "Replace all occurrences if true", required: false

      MAX_FILE_SIZE = 1_000_000

      def execute(path:, old_string:, new_string:, replace_all: false)
        path = File.expand_path(path)

        unless File.exist?(path)
          return Ask::Result.error(message: "File does not exist: #{path}")
        end

        unless File.file?(path)
          return Ask::Result.error(message: "Not a file: #{path}")
        end

        if File.size(path) > MAX_FILE_SIZE
          return Ask::Result.error(
            message: "File too large (#{File.size(path)} bytes). Maximum is #{MAX_FILE_SIZE} bytes."
          )
        end

        content = File.read(path)

        if replace_all
          count = content.scan(old_string).size
          return Ask::Result.error(message: "String not found") if count == 0
          content = content.gsub(old_string, new_string)
        else
          index = content.index(old_string)
          return Ask::Result.error(message: "String not found") unless index
          count = 1
          content = content.sub(old_string, new_string)
        end

        File.write(path, content)
        Ask::Result.ok(data: { path: path, replacements: count },
                        metadata: { path: path, replacements: count })
      end
    end
  end
end
