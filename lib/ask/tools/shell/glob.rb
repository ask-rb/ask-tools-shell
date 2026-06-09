# frozen_string_literal: true

module Ask
  module Tools
    # Find files matching a glob pattern, newest first.
    class Glob < Ask::Tool
      description "Find files matching a glob pattern. " \
                   "Returns up to 1000 matching file paths sorted by modification time (newest first)."

      param :pattern, type: :string, desc: "Glob pattern (e.g. **/*.rb)", required: true
      param :path, type: :string, desc: "Base directory (default: current)", required: false

      MAX_RESULTS = 1000

      def execute(pattern:, path: nil)
        base = path ? File.expand_path(path) : Dir.pwd

        unless File.directory?(base)
          return Ask::Result.error(message: "Directory does not exist: #{base}")
        end

        files = Dir.glob(pattern, base: base).map { |f| File.join(base, f) }
        files = files.select { |f| File.file?(f) }
        files = files.sort_by { |f| -File.mtime(f).to_i }
        files = files.first(MAX_RESULTS)

        if files.empty?
          return Ask::Result.error(message: "No files found matching: #{pattern}")
        end

        result = files.join("\n")
        result << "\n... (#{files.size} files shown)" if files.size == MAX_RESULTS

        Ask::Result.ok(data: result, metadata: { count: files.size, truncated: files.size == MAX_RESULTS })
      end
    end
  end
end
