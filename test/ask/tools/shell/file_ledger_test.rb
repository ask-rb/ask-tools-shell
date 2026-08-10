# frozen_string_literal: true

require_relative "../../../test_helper"
require "tmpdir"

module Ask
  module Tools
    class FileLedgerTest < Minitest::Test
      def teardown
        Ask::Tools::Shell::FileLedger.reset!
      end

      def test_record_and_lookup
        Dir.mktmpdir do |dir|
          path = File.join(dir, "f.txt")
          File.write(path, "abc")
          Ask::Tools::Shell::FileLedger.record(path, partial: true, lines_seen: [0, 2])

          entry = Ask::Tools::Shell::FileLedger.entry_for(path)
          refute_nil entry
          assert entry[:partial]
          assert_equal [0, 2], entry[:lines_seen]
          assert_equal File.size(path), entry[:size]
        end
      end

      def test_partially_seen
        Dir.mktmpdir do |dir|
          path = File.join(dir, "f.txt")
          File.write(path, "abc")
          Ask::Tools::Shell::FileLedger.record(path, partial: true, lines_seen: [0, 2])
          assert Ask::Tools::Shell::FileLedger.partially_seen?(path)

          Ask::Tools::Shell::FileLedger.record(path, partial: false, lines_seen: [0, 3])
          refute Ask::Tools::Shell::FileLedger.partially_seen?(path)
        end
      end

      def test_stale_entry_invalidated_by_changed_file
        Dir.mktmpdir do |dir|
          path = File.join(dir, "f.txt")
          File.write(path, "abc")
          Ask::Tools::Shell::FileLedger.record(path, partial: true, lines_seen: [0, 2])

          # File changed: mtime and size both differ from the recorded read.
          File.write(path, "much longer content")
          File.utime(Time.now + 10, Time.now + 10, path)
          assert_nil Ask::Tools::Shell::FileLedger.entry_for(path)
          refute Ask::Tools::Shell::FileLedger.partially_seen?(path)
        end
      end

      def test_entries_for_deleted_file_are_stale
        Dir.mktmpdir do |dir|
          path = File.join(dir, "f.txt")
          File.write(path, "abc")
          Ask::Tools::Shell::FileLedger.record(path, partial: true, lines_seen: [0, 2])
          File.delete(path)
          assert_nil Ask::Tools::Shell::FileLedger.entry_for(path)
        end
      end

      def test_reset_clears
        Dir.mktmpdir do |dir|
          path = File.join(dir, "f.txt")
          File.write(path, "abc")
          Ask::Tools::Shell::FileLedger.record(path, partial: true, lines_seen: [0, 2])
          Ask::Tools::Shell::FileLedger.reset!
          assert_nil Ask::Tools::Shell::FileLedger.entry_for(path)
        end
      end
    end
  end
end
