# frozen_string_literal: true

module Ask
  module Tools
    module Shell
      # Queues file mutations and applies them atomically.
      # Rollback on any failure — no partial writes.
      #
      #   queue = FileMutationQueue.new
      #   queue.stage("path/to/file.rb", ->(content) {
      #     content.gsub("old", "new")
      #   })
      #   queue.apply!  # reads all staged files, applies transforms, writes back
      #
      class FileMutationQueue
        class ApplyError < StandardError; end

        def initialize(operations: nil)
          @staged = []
          @operations = operations || DefaultEditOperations.new
        end

        # Stage a mutation for a file.
        # @param path [String] absolute path to the file
        # @yield [content] raw file content, returns modified content
        # @yieldparam content [String] the original file content
        # @yieldreturn [String] the modified content
        def stage(path, &block)
          @staged << { path: File.expand_path(path), block: block }
        end

        # Apply all staged mutations atomically.
        # Reads all files, applies transforms, then writes all back.
        # If any write fails, all written files are rolled back to original.
        # @return [Array<Hash>] results with :path, :original_size, :new_size, :success
        # @raise [ApplyError] if any mutation fails (after rollback)
        def apply!
          snapshots = []

          # Phase 1: read all files and apply transforms
          @staged.each do |entry|
            path = entry[:path]
            original = @operations.read_file(path)
            modified = entry[:block].call(original)
            snapshots << { path: path, original: original, modified: modified }
          end

          # Phase 2: write all files, track rollback info
          written = []
          begin
            snapshots.each do |s|
              @operations.write_file(s[:path], s[:modified])
              written << s[:path]
            end
          rescue => e
            # Rollback: restore originals for files we already wrote
            written.each do |path|
              snapshot = snapshots.find { |s| s[:path] == path }
              @operations.write_file(path, snapshot[:original]) if snapshot
            rescue => rb_e
              $stderr.puts "[FileMutationQueue] Rollback failed for #{path}: #{rb_e.message}"
            end
            raise ApplyError, "Mutation failed at #{e.class}: #{e.message}. Rolled back #{written.size} files."
          end

          snapshots.map do |s|
            { path: s[:path], original_size: s[:original].length,
              new_size: s[:modified].length, success: true }
          end
        end

        # Clear all staged mutations without applying.
        def clear!
          @staged.clear
        end

        # Number of staged mutations.
        def size
          @staged.size
        end
      end
    end
  end
end
