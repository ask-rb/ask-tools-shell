# frozen_string_literal: true

require "monitor"

module Ask
  module Tools
    module Shell
      # Records what Read has shown of each file, so Write can refuse to
      # destroy content the model never saw. Entries are validated against
      # the file's current mtime/size — a changed file invalidates its
      # entry, so a stale ledger can never block a write it shouldn't.
      #
      # Class-level on purpose: a partial view is a fact about the world,
      # not about one tool instance (agent sessions new up fresh tool
      # instances, and the invariant must survive across them).
      class FileLedger
        Entry = Struct.new(:path, :mtime, :size, :partial, :lines_seen, keyword_init: true)

        @entries = {}
        @mutex = Monitor.new

        class << self
          # Record what a read showed of a file.
          # @param partial [Boolean] true when the view was clamped/truncated
          # @param lines_seen [Array(Integer, Integer)] [start, stop) line
          #   indices shown, 0-indexed
          def record(path, partial:, lines_seen:)
            path = File.expand_path(path)
            @mutex.synchronize do
              @entries[path] = Entry.new(
                path: path,
                mtime: File.mtime(path),
                size: File.size(path),
                partial: partial,
                lines_seen: lines_seen
              )
            end
          rescue Errno::ENOENT
            nil # file vanished mid-read; nothing to record
          end

          # The entry for a path, or nil when the file changed since the read.
          def entry_for(path)
            path = File.expand_path(path)
            @mutex.synchronize do
              entry = @entries[path]
              next nil unless entry

              current = File.stat(path)
              (current.mtime == entry.mtime && current.size == entry.size) ? entry : nil
            end
          rescue Errno::ENOENT
            nil
          end

          # True when the file was only partially read and hasn't changed
          # since. Write consults this before overwriting.
          def partially_seen?(path)
            entry = entry_for(path)
            !entry.nil? && entry.partial
          end

          def reset!
            @mutex.synchronize { @entries.clear }
          end
        end
      end
    end
  end
end
