# frozen_string_literal: true

require "fileutils"

module Ask
  module Tools
    # Read file contents with line numbers, or list directory contents.
    # Output is truncated to 2000 lines.
    class Read < Ask::Tool
      description "Read the contents of a file or list a directory. " \
                   "Files are displayed with line numbers. " \
                   "Output is truncated to 2000 lines."

      param :path, type: :string, desc: "Absolute path to the file or directory", required: true
      param :offset, type: :integer, desc: "Starting line number (0-indexed)", required: false
      param :limit, type: :integer, desc: "Maximum number of lines to read", required: false

      MAX_LINES = 2000

      def execute(path:, offset: nil, limit: nil)
        path = File.expand_path(path)

        unless File.exist?(path)
          return Ask::Result.error(message: "Path does not exist: #{path}")
        end

        if File.directory?(path)
          entries = Dir.children(path).sort
          entries.map! do |e|
            full = File.join(path, e)
            "#{e}#{File.directory?(full) ? '/' : ''}"
          end
          return Ask::Result.ok(data: entries.join("\n"), metadata: { type: "directory", count: entries.size })
        end

        unless File.file?(path)
          return Ask::Result.error(message: "Not a file: #{path}")
        end

        if File.size(path) > 1_000_000
          return Ask::Result.error(
            message: "File too large (#{File.size(path)} bytes). Use offset/limit to read portions."
          )
        end

        lines = File.readlines(path, chomp: true)
        total = lines.size
        offset_val = offset.to_i.clamp(0, total)
        limit_val = limit || MAX_LINES

        selected = lines[offset_val, limit_val]
        truncated = selected.size < (total - offset_val)

        result = selected.each_with_index.map do |line, i|
          "#{offset_val + i + 1}: #{line}"
        end.join("\n")

        result << "\n... (#{total - offset_val - selected.size} more lines)" if truncated

        Ask::Result.ok(data: result, metadata: {
          total_lines: total,
          start_line: offset_val + 1,
          end_line: offset_val + selected.size,
          truncated: truncated
        })
      end
    end
  end
end
