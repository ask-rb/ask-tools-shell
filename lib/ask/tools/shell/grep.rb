# frozen_string_literal: true

module Ask
  module Tools
    # Search file contents using a regex pattern.
    class Grep < Ask::Tool
      description "Search file contents using a regex pattern. " \
                   "Returns matching file paths with line numbers and content. " \
                   "Truncated to 100 matches with line content capped at 500 chars."

      param :pattern, type: :string, desc: "Regex pattern to search for", required: true
      param :path, type: :string, desc: "Directory to search in (default: current)", required: false
      param :include, type: :string, desc: "File pattern filter (e.g. *.rb)", required: false

      MAX_MATCHES = 100
      MAX_LINE_LENGTH = 500
      EXCLUDE_DIRS = %w[.git node_modules vendor .bundle tmp log].freeze

      def execute(pattern:, path: nil, include: nil)
        base = path ? File.expand_path(path) : Dir.pwd

        unless File.directory?(base)
          return Ask::Result.error(message: "Directory does not exist: #{base}")
        end

        begin
          regex = Regexp.new(pattern, Regexp::IGNORECASE)
        rescue RegexpError => e
          return Ask::Result.error(message: "Invalid regex: #{e.message}")
        end

        matches = []
        glob = include || "**/*"

        Dir.glob(File.join(base, glob)).each do |file|
          next unless File.file?(file)
          next if EXCLUDE_DIRS.any? { |d| file.include?("/#{d}/") }

          begin
            File.readlines(file).each_with_index do |line, i|
              next unless regex.match?(line)
              line_text = line.chomp
              line_text = line_text[0, MAX_LINE_LENGTH] + "..." if line_text.length > MAX_LINE_LENGTH
              matches << "#{file}:#{i + 1}: #{line_text}"
              if matches.size >= MAX_MATCHES
                return Ask::Result.ok(data: matches.join("\n") + "\n... (too many matches)",
                                       metadata: { count: matches.size, truncated: true })
              end
            end
          rescue => e
            matches << "#{file}: error reading: #{e.message}"
          end
        end

        if matches.empty?
          return Ask::Result.error(message: "No matches found for: #{pattern}")
        end

        Ask::Result.ok(data: matches.join("\n"), metadata: { count: matches.size, truncated: false })
      end
    end
  end
end
