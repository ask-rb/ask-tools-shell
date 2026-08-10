# frozen_string_literal: true

require "fileutils"

module Ask
  module Tools
    # Write content to a file, creating parent directories automatically.
    class Write < Ask::Tool
      description "Write content to a file at the specified path. " \
                   "Creates parent directories automatically. " \
                   "Returns the path and number of bytes written."

      param :path, type: :string, desc: "Absolute path to write to", required: true
      param :content, type: :string, desc: "File content to write", required: true

      MAX_CONTENT_SIZE = 500_000

      def execute(path:, content:)
        path = File.expand_path(path)

        if content.length > MAX_CONTENT_SIZE
          return Ask::Result.error(
            message: "Content too large (#{content.length} bytes). Maximum is #{MAX_CONTENT_SIZE} bytes."
          )
        end

        # Never destroy what the model never saw: if Read only showed part of
        # this file and it hasn't changed since, the rest may hold something
        # the overwrite would silently erase.
        if Shell::FileLedger.partially_seen?(path)
          entry = Shell::FileLedger.entry_for(path)
          seen = entry.lines_seen
          return Ask::Result.error(
            message: "Refusing to overwrite #{path}: only part of the file has been read " \
                     "(lines #{seen.first + 1}–#{seen.last} shown, more lines exist). " \
                     "Re-read the full file first."
          )
        end

        dir = File.dirname(path)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)

        bytes = File.write(path, content)
        Ask::Result.ok(data: { path: path, bytes: bytes },
                        metadata: { path: path, bytes: bytes })
      end
    end
  end
end
