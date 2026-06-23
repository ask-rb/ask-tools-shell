# frozen_string_literal: true

require "fileutils"

module Ask
  module Tools
    module Shell
      module ApplyPatchOperations
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

        def delete_file(path)
          File.delete(path)
        end

        def expand_path(path)
          File.expand_path(path)
        end

        def mkdir_p(path)
          FileUtils.mkdir_p(File.dirname(path))
        end
      end

      class DefaultApplyPatchOperations
        include ApplyPatchOperations
      end
    end

    # Apply a patch to files using a unified diff format.
    # Supports creating, updating, and deleting files within a
    # "*** Begin Patch" / "*** End Patch" envelope.
    class ApplyPatch < Ask::Tool
      description "Edit files using a unified diff format. " \
                   "Wrap all changes in a \"*** Begin Patch\" / \"*** End Patch\" envelope. " \
                   "Each file section starts with a header: " \
                   "\"*** Add File: <path>\" for new files, " \
                   "\"*** Update File: <path>\" for changes, or " \
                   "\"*** Delete File: <path>\" for removals. " \
                   "Prefix new lines with +."

      param :patchText, type: :string, desc: "The full patch text describing all file changes", required: true

      attr_writer :operations

      def operations
        @operations ||= Shell::DefaultApplyPatchOperations.new
      end

      MAX_FILE_SIZE = 10_000_000

      def execute(patchText:)
        patches = parse_patch(patchText)
        return Ask::Result.error(message: "No valid patch sections found") if patches.empty?

        results = []
        patches.each do |entry|
          path = operations.expand_path(entry[:path])

          case entry[:type]
          when :add
            if operations.file_exist?(path)
              return Ask::Result.error(message: "File already exists: #{path}")
            end
            operations.mkdir_p(path)
            content = entry[:lines].join("\n")
            content += "\n" unless content.end_with?("\n")
            operations.write_file(path, content)
            results << { action: "add", path: entry[:path], lines: entry[:lines].size }

          when :update
            unless operations.file_exist?(path)
              return Ask::Result.error(message: "File does not exist: #{path}")
            end
            unless operations.file?(path)
              return Ask::Result.error(message: "Not a file: #{path}")
            end

            raw = operations.read_file(path)
            size = raw.bytesize
            if size > MAX_FILE_SIZE
              return Ask::Result.error(message: "File too large (#{size} bytes)")
            end

            new_content = apply_chunks(raw, entry[:chunks])
            operations.write_file(path, new_content)
            results << { action: "update", path: entry[:path] }

          when :delete
            unless operations.file_exist?(path)
              return Ask::Result.error(message: "File does not exist: #{path}")
            end
            operations.delete_file(path)
            results << { action: "delete", path: entry[:path] }
          end
        end

        summary = results.map { |r| "#{r[:action].upcase_first} #{r[:path]}" }.join("\n")
        Ask::Result.ok(data: { summary: summary, results: results }, metadata: { results: results })
      end

      private

      PATCH_START = "*** Begin Patch"
      PATCH_END = "*** End Patch"
      ADD_HEADER = /^\*\*\* Add File:\s+(.+)/i
      UPDATE_HEADER = /^\*\*\* Update File:\s+(.+)/i
      DELETE_HEADER = /^\*\*\* Delete File:\s+(.+)/i
      HUNK_HEADER = /^@@/

      def parse_patch(text)
        text = text.dup.force_encoding("UTF-8")
        start_idx = text.index(PATCH_START)
        return [] unless start_idx

        after_start = text[(start_idx + PATCH_START.length)..]
        end_idx = after_start.index(PATCH_END)
        body = end_idx ? after_start[0...end_idx] : after_start

        entries = []
        lines = body.split("\n")
        i = 0
        while i < lines.length
          line = lines[i]

          if (m = line.match(ADD_HEADER))
            path = m[1].strip
            i += 1
            content_lines = []
            while i < lines.length && !lines[i].start_with?("***")
              content_lines << lines[i].sub(/^\+/, "") if lines[i].start_with?("+")
              i += 1
            end
            entries << { type: :add, path: path, lines: content_lines }

          elsif (m = line.match(UPDATE_HEADER))
            path = m[1].strip
            i += 1
            chunks = []
            while i < lines.length && !lines[i].start_with?("***")
              if lines[i].match?(HUNK_HEADER)
                i += 1
                old_lines = []
                new_lines = []
                while i < lines.length && !lines[i].start_with?("***") && !lines[i].match?(HUNK_HEADER) && !lines[i].start_with?("***")
                  if lines[i].start_with?("-")
                    old_lines << lines[i][1..]
                  elsif lines[i].start_with?("+")
                    new_lines << lines[i][1..]
                  elsif lines[i].start_with?(" ")
                    old_lines << lines[i][1..]
                    new_lines << lines[i][1..]
                  end
                  i += 1
                end
                chunks << { old: old_lines, new: new_lines } unless old_lines.empty? && new_lines.empty?
              else
                i += 1
              end
            end
            entries << { type: :update, path: path, chunks: chunks }

          elsif (m = line.match(DELETE_HEADER))
            entries << { type: :delete, path: m[1].strip }
            i += 1

          else
            i += 1
          end
        end

        entries
      end

      def apply_chunks(content, chunks)
        return content if chunks.empty?

        lines = content.split("\n", -1)
        chunks.each do |chunk|
          old_text = chunk[:old].join("\n")
          new_text = chunk[:new].join("\n")
          file_text = lines.join("\n")
          idx = file_text.index(old_text)
          next unless idx

          before = file_text[0...idx]
          after = file_text[(idx + old_text.length)..]
          file_text = before + new_text + after
          lines = file_text.split("\n", -1)
        end
        lines.join("\n")
      end
    end
  end
end
