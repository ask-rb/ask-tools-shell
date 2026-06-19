# frozen_string_literal: true

module Ask
  module Tools
    module Shell
      # Pluggable operations for the Edit tool.
      module EditOperations
        def read_file(path)
          File.read(path)
        end

        def write_file(path, content)
          File.write(path, content)
        end

        def file_exist?(path)
          File.exist?(path)
        end

        def file?(path)
          File.file?(path)
        end

        def file_size(path)
          File.size(path)
        end

        def expand_path(path)
          File.expand_path(path)
        end
      end

      class DefaultEditOperations
        include EditOperations
      end

      # Strip UTF-8 BOM from content. Returns { bom: String, text: String }.
      def self.strip_bom(content)
        bom = content.byteslice(0, 3) == "\xEF\xBB\xBF" ? content.byteslice(0, 3) : ""
        [bom, bom.empty? ? content : content.byteslice(3..)]
      end

      # Detect the dominant line ending in content.
      def self.detect_line_ending(content)
        crlf = content.count("\r\n")
        lf = content.count("\n") - crlf
        crlf > lf ? "\r\n" : "\n"
      end

      # Normalize line endings to LF.
      def self.normalize_line_endings(content)
        content.gsub("\r\n", "\n").gsub("\r", "\n")
      end

      # Restore original line endings after normalization.
      def self.restore_line_endings(content, original_ending)
        return content if original_ending == "\n"
        content.gsub("\n", original_ending)
      end
    end

    # Edit a file by replacing exact text. Supports BOM, line-ending preservation.
    class Edit < Ask::Tool
      description "Edit a file by replacing exact text."

      param :path, type: :string, desc: "Absolute path to the file", required: true
      param :old_string, type: :string, desc: "Exact text to replace", required: true
      param :new_string, type: :string, desc: "Replacement text", required: true
      param :replace_all, type: :boolean, desc: "Replace all occurrences if true", required: false

      MAX_FILE_SIZE = 1_000_000

      attr_writer :operations

      def operations
        @operations ||= Shell::DefaultEditOperations.new
      end

      def execute(path:, old_string:, new_string:, replace_all: false)
        path = operations.expand_path(path)

        unless operations.file_exist?(path)
          return Ask::Result.error(message: "File does not exist: " + path)
        end

        unless operations.file?(path)
          return Ask::Result.error(message: "Not a file: " + path)
        end

        size = operations.file_size(path)
        if size > MAX_FILE_SIZE
          return Ask::Result.error(
            message: "File too large (#{size} bytes). Maximum is #{MAX_FILE_SIZE} bytes."
          )
        end

        raw = operations.read_file(path)
        bom, content = Shell.strip_bom(raw)
        original_ending = Shell.detect_line_ending(content)
        content = Shell.normalize_line_endings(content)

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

        # Restore line endings and re-add BOM
        content = Shell.restore_line_endings(content, original_ending)
        content = bom + content

        operations.write_file(path, content)
        Ask::Result.ok(data: { path: path, replacements: count },
                        metadata: { path: path, replacements: count })
      end
    end
  end
end
