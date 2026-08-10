# frozen_string_literal: true

require_relative "../../../test_helper"
require "tempfile"
require "tmpdir"

module Ask
  module Tools
    class ReadTest < Minitest::Test
      def setup
        @tool = Read.new
        @tmpfile = Tempfile.new(["read_test", ".txt"])
        @tmpfile.write("line one\nline two\nline three\n")
        @tmpfile.close
      end

      def teardown
        @tmpfile.unlink
      end

      def test_tool_name
        assert_equal "read", @tool.name
      end

      def test_read_file
        result = @tool.call(path: @tmpfile.path)
        assert_predicate result, :ok?
        assert_match(/line one/, result.output)
        assert_match(/line two/, result.output)
        assert_match(/line three/, result.output)
      end

      def test_read_with_line_numbers
        result = @tool.call(path: @tmpfile.path)
        assert_predicate result, :ok?
        assert_match(/1: line one/, result.output)
        assert_match(/2: line two/, result.output)
        assert_match(/3: line three/, result.output)
      end

      def test_read_with_offset
        result = @tool.call(path: @tmpfile.path, offset: 1)
        assert_predicate result, :ok?
        refute_match(/1: line one/, result.output)
        assert_match(/2: line two/, result.output)
      end

      def test_read_with_limit
        result = @tool.call(path: @tmpfile.path, limit: 1)
        assert_predicate result, :ok?
        assert_match(/1: line one/, result.output)
        refute_match(/2: line two/, result.output)
      end

      def test_read_nonexistent_path
        result = @tool.call(path: "/tmp/nonexistent_file_12345")
        refute_predicate result, :ok?
        assert_match(/does not exist/i, result.error)
      end

      def test_read_directory
        result = @tool.call(path: Dir.pwd)
        assert_predicate result, :ok?
        assert_kind_of String, result.output
      end

      def test_missing_path_param
        result = @tool.call({})
        refute_predicate result, :ok?
        assert_match(/missing required parameter/, result.error)
      end

      # ── Three ceilings: line window, byte budget, per-line clamp ──

      def test_byte_budget_truncates_and_suggests_resume_offset
        Dir.mktmpdir do |dir|
          path = File.join(dir, "wide.txt")
          File.write(path, (1..50).map { |i| "line #{i} " + "x" * 30 }.join("\n"))
          tool = Read.new
          tool.byte_budget = 500
          result = tool.call(path: path)
          assert_predicate result, :ok?
          assert_match(/more lines/, result.output)
          assert_match(/resume with offset=\d+/, result.output)
          resume = result.output[/resume with offset=(\d+)/, 1].to_i
          assert_operator resume, :>, 0
          assert_operator result.output.length, :<=, 500 + 200 # slack for the hint
          assert result.metadata[:truncated]
          assert result.metadata[:partial_view]
          refute result.metadata[:total_lines] # unknown when truncated
        end
      end

      def test_per_line_clamp_marks_long_lines
        Dir.mktmpdir do |dir|
          path = File.join(dir, "minified.js")
          File.write(path, "short line\n" + "y" * 5000 + "\nshort again\n")
          tool = Read.new
          tool.max_line_chars = 100
          result = tool.call(path: path)
          assert_predicate result, :ok?
          assert_match(/clamped/, result.output)
          refute_match(/y{5000}/, result.output)
          assert_equal 1, result.metadata[:clamped_lines]
          assert result.metadata[:partial_view]
        end
      end

      # ── Named recovery: facts, not errors ──

      def test_empty_file_returns_note_not_error
        Dir.mktmpdir do |dir|
          path = File.join(dir, "empty.txt")
          File.write(path, "")
          result = @tool.call(path: path)
          assert_predicate result, :ok?
          assert_match(/empty/i, result.output)
        end
      end

      def test_offset_past_end_hints_retry_smaller
        Dir.mktmpdir do |dir|
          path = File.join(dir, "small.txt")
          File.write(path, "a\nb\n")
          result = @tool.call(path: path, offset: 10)
          assert_predicate result, :ok?
          assert_match(/past the end/i, result.output)
        end
      end

      def test_binary_file_returns_mime_note
        Dir.mktmpdir do |dir|
          path = File.join(dir, "image.png")
          File.binwrite(path, "\x89PNG\r\n\x1a\n".b + ("\x00\x01\x02".b * 100))
          result = @tool.call(path: path)
          assert_predicate result, :ok?
          assert_match(/binary/i, result.output)
          assert_match(/png/i, result.output)
        end
      end

      def test_pdf_returns_pdftotext_hint
        Dir.mktmpdir do |dir|
          path = File.join(dir, "doc.pdf")
          File.binwrite(path, "%PDF-1.4\n" + "\x00".b * 50)
          result = @tool.call(path: path)
          assert_predicate result, :ok?
          assert_match(/pdftotext/i, result.output)
        end
      end

      # ── Hygiene: BOM, CRLF, UTF-8 ──

      def test_read_strips_bom
        Dir.mktmpdir do |dir|
          path = File.join(dir, "bom.txt")
          File.binwrite(path, "\xEF\xBB\xBFfirst line\nsecond line")
          result = @tool.call(path: path)
          assert_predicate result, :ok?
          assert_match(/^1: first line/, result.output)
          refute_match(/\xEF\xBB\xBF/, result.output)
        end
      end

      def test_read_normalizes_crlf
        Dir.mktmpdir do |dir|
          path = File.join(dir, "crlf.txt")
          File.binwrite(path, "one\r\ntwo\r\nthree\r\n")
          result = @tool.call(path: path)
          assert_predicate result, :ok?
          refute_match(/\r/, result.output)
          assert_match(/^2: two$/, result.output)
        end
      end

      # ── Input repair: coerce, don't silently mangle ──

      def test_read_accepts_numeric_string_offset
        Dir.mktmpdir do |dir|
          path = File.join(dir, "nums.txt")
          File.write(path, "a\nb\nc\n")
          result = @tool.call(path: path, offset: "1")
          assert_predicate result, :ok?
          assert_match(/^2: b/, result.output)
        end
      end

      def test_read_rejects_garbage_offset
        result = @tool.call(path: @tmpfile.path, offset: "2abc")
        refute_predicate result, :ok?
        assert_match(/invalid offset/i, result.error)
      end

      def test_read_rejects_fractional_offset
        result = @tool.call(path: @tmpfile.path, offset: 1.5)
        refute_predicate result, :ok?
        assert_match(/invalid offset/i, result.error)
      end

      def test_read_rejects_negative_offset
        result = @tool.call(path: @tmpfile.path, offset: -3)
        refute_predicate result, :ok?
        assert_match(/invalid offset/i, result.error)
      end

      def test_read_rejects_nonpositive_limit
        result = @tool.call(path: @tmpfile.path, limit: 0)
        refute_predicate result, :ok?
        assert_match(/invalid limit/i, result.error)
      end

      # ── Device blocklist: refused by name before any I/O ──

      def test_read_refuses_device_files
        ["/dev/zero", "/dev/random", "/dev/urandom",
         "/dev/stdin", "/dev/stdout", "/dev/stderr",
         "/dev/fd/0", "/proc/123/fd/0"].each do |dev|
          result = @tool.call(path: dev)
          refute_predicate result, :ok?, "expected refusal for #{dev}"
          assert_match(/device/i, result.error)
        end
      end

      # ── Filename repair: unicode variants + did you mean ──

      def test_filename_variants_include_nfd_and_nfc
        # Unit-level: APFS resolves NFD/NFC transparently, so the repair
        # only fires on byte-exact filesystems (Linux, Windows). The variant
        # list itself is the contract.
        nfc = "café.txt" # composed
        nfd = nfc.unicode_normalize(:nfd)
        assert_includes @tool.send(:filename_variants, nfc), nfd
        assert_includes @tool.send(:filename_variants, nfd), nfc
      end

      def test_filename_variants_include_nbsp_swap
        variants = @tool.send(:filename_variants, "Screenshot 3.04\u202FPM.png")
        assert_includes variants, "Screenshot 3.04 PM.png" # narrow NBSP → plain space
        assert_includes variants, "Screenshot\u202F3.04\u202FPM.png" # plain space → narrow NBSP
      end

      def test_read_suggests_close_match_for_curly_quote
        Dir.mktmpdir do |dir|
          File.write(File.join(dir, "it's.txt"), "x")
          result = @tool.call(path: File.join(dir, "it\u2019s.txt"))
          refute_predicate result, :ok?
          assert_match(/close match/i, result.error)
          assert_match(/it's\.txt/, result.error)
        end
      end

      def test_read_did_you_mean_levenshtein
        Dir.mktmpdir do |dir|
          File.write(File.join(dir, "AGENTS.md"), "x")
          result = @tool.call(path: File.join(dir, "AGENT.md"))
          refute_predicate result, :ok?
          assert_match(/did you mean/i, result.error)
          assert_match(/AGENTS\.md/, result.error)
        end
      end

      def test_read_did_you_mean_substring
        Dir.mktmpdir do |dir|
          File.write(File.join(dir, "verylongfilename.rb"), "x")
          result = @tool.call(path: File.join(dir, "longfilename.rb"))
          refute_predicate result, :ok?
          assert_match(/did you mean/i, result.error)
          assert_match(/verylongfilename\.rb/, result.error)
        end
      end

      # ── Dedup: self-expiring stub, complete reads only, kill switch ──

      def test_dedup_returns_stub_once_then_content
        Dir.mktmpdir do |dir|
          path = File.join(dir, "stable.txt")
          File.write(path, "stable content\nsecond line\n")
          tool = Read.new
          first = tool.call(path: path)
          second = tool.call(path: path)
          third = tool.call(path: path)
          assert_predicate first, :ok?
          assert_predicate second, :ok?
          assert_predicate third, :ok?
          assert_match(/stable content/, first.output)
          assert_match(/already in context/i, second.output)
          assert_match(/stable content/, third.output) # self-expiring: content again
        end
      end

      def test_dedup_skips_truncated_reads
        Dir.mktmpdir do |dir|
          path = File.join(dir, "big.txt")
          File.write(path, (1..50).map { |i| "line #{i}" }.join("\n"))
          tool = Read.new
          tool.max_lines = 10
          first = tool.call(path: path)
          second = tool.call(path: path)
          refute_match(/already in context/i, second.output)
          assert_match(/^1: line 1/, second.output)
        end
      end

      def test_dedup_kill_switch_env
        Dir.mktmpdir do |dir|
          path = File.join(dir, "stable.txt")
          File.write(path, "content\n")
          ENV["ASK_TOOLS_SHELL_READ_NO_CACHE"] = "1"
          begin
            tool = Read.new
            tool.call(path: path)
            second = tool.call(path: path)
            refute_match(/already in context/i, second.output)
          ensure
            ENV.delete("ASK_TOOLS_SHELL_READ_NO_CACHE")
          end
        end
      end

      # ── Streaming: stops at budget instead of loading the whole file ──

      def test_read_large_file_stops_at_budget
        Dir.mktmpdir do |dir|
          path = File.join(dir, "big.log")
          File.open(path, "w") { |f| 50_000.times { |i| f.puts("log line #{i} " + "x" * 50) } }
          tool = Read.new
          tool.byte_budget = 2000
          result = tool.call(path: path)
          assert_predicate result, :ok?
          assert_operator result.output.length, :<=, 3000
          assert_match(/more lines/, result.output)
          assert_match(/resume with offset=\d+/, result.output)
        end
      end
    end
  end
end
