# frozen_string_literal: true

require "fileutils"

module Ask
  module Tools
    # Read file contents with line numbers, or list directory contents.
    #
    # Engineered for token budgets. Three ceilings stop the three shapes of
    # hostile file — the long file (line window), the wide file (byte
    # budget), the minified bundle (per-line clamp):
    #
    #   max_lines      = 2000 lines  — the window
    #   byte_budget    = 128 KB      — chars of output returned
    #   max_line_chars = 2000        — per-line clamp
    #
    # Truncation is a fact, not an error: reads that stop short return ok
    # with a precomputed resume offset, so the model never does pagination
    # arithmetic and never treats a fact about the world as a failure.
    #
    # The other decisions that make a read cheap instead of expensive:
    #   - strict offset/limit repair (never silently mangle "2abc" into 2)
    #   - device blocklist — /dev/zero would hang a read forever
    #   - filename repair: NFD/NFC, narrow NBSP, curly quotes, did-you-mean
    #   - a self-expiring dedup stub for unchanged re-reads (consumed on use,
    #     complete reads only, kill-switchable)
    #   - a partial-view ledger that Write consults before overwriting
    class Read < Ask::Tool
      description "Read the contents of a file or list a directory. " \
                   "Files are displayed with line numbers. Output is bounded " \
                   "to 2000 lines and 128 KB, with resume hints when truncated."

      param :path, type: :string, desc: "Absolute path to the file or directory", required: true
      param :offset, type: :integer, desc: "Starting line number (0-indexed)", required: false
      param :limit, type: :integer, desc: "Maximum number of lines to read", required: false

      DEFAULT_MAX_LINES = 2000
      DEFAULT_BYTE_BUDGET = 128_000
      DEFAULT_MAX_LINE_CHARS = 2000

      # Device files that never end or block forever — refused by name
      # before any I/O, so a read can never hang on them.
      DEVICE_PATHS = %w[
        /dev/zero /dev/random /dev/urandom
        /dev/stdin /dev/stdout /dev/stderr
      ].freeze

      MIME_TYPES = {
        ".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg",
        ".gif" => "image/gif", ".webp" => "image/webp", ".svg" => "image/svg+xml",
        ".pdf" => "application/pdf", ".zip" => "application/zip",
        ".gz" => "application/gzip", ".mp3" => "audio/mpeg", ".mp4" => "video/mp4"
      }.freeze

      attr_reader :max_lines, :byte_budget, :max_line_chars, :dedup_enabled
      attr_writer :max_lines, :byte_budget, :max_line_chars

      def initialize
        super
        @max_lines = DEFAULT_MAX_LINES
        @byte_budget = (ENV["ASK_TOOLS_SHELL_READ_BYTE_BUDGET"] || DEFAULT_BYTE_BUDGET).to_i
        @max_line_chars = DEFAULT_MAX_LINE_CHARS
        @dedup_enabled = ENV["ASK_TOOLS_SHELL_READ_NO_CACHE"] != "1"
        @dedup = {}
      end

      def execute(path:, offset: nil, limit: nil)
        path = File.expand_path(path)

        if device_path?(path)
          return Ask::Result.error(message: "Refusing to read device file: #{path} (can block forever).")
        end

        unless File.exist?(path)
          return Ask::Result.error(message: missing_path_message(path))
        end

        if File.directory?(path)
          return directory_listing(path)
        end

        unless File.file?(path)
          return Ask::Result.error(message: "Not a file: #{path}")
        end

        offset = coerce_int("offset", offset)
        return Ask::Result.error(message: offset) if offset.is_a?(String)
        limit = coerce_int("limit", limit)
        return Ask::Result.error(message: limit) if limit.is_a?(String)

        offset ||= 0
        limit ||= @max_lines
        return Ask::Result.error(message: "Invalid offset: #{offset} (must be >= 0).") if offset.negative?
        return Ask::Result.error(message: "Invalid limit: #{limit} (must be >= 1).") if limit < 1

        special = sniff(path)
        return special if special

        read = read_lines(path, offset, limit)
        partial_view = read[:more] || read[:clamped].positive?

        if @dedup_enabled && !partial_view && read[:lines].any?
          key = [path, File.mtime(path).to_f, File.size(path), offset, limit]
          if @dedup.key?(key)
            @dedup.delete(key) # self-expiring: one stub, then real content again
            return Ask::Result.ok(
              data: "File unchanged since last read — content is already in context.",
              metadata: { dedup: true }
            )
          end
          @dedup[key] = true
        end

        Shell::FileLedger.record(path, partial: partial_view, lines_seen: [offset, offset + read[:lines].size])

        data, resume_offset = format_output(path, offset, read)

        metadata = {
          total_lines: read[:more] || (read[:lines].empty? && read[:saw_any]) ? nil : offset + read[:lines].size,
          start_line: read[:lines].empty? ? nil : offset + 1,
          end_line: offset + read[:lines].size,
          truncated: read[:more],
          partial_view: partial_view,
          clamped_lines: read[:clamped],
          resume_offset: resume_offset
        }
        metadata.delete(:resume_offset) unless read[:more]
        Ask::Result.ok(data: data, metadata: metadata)
      end

      private

      # ── the three ceilings ─────────────────────────────────────────────

      # Stream the file line by line (never load the whole thing), stopping
      # at the line window, the byte budget, or EOF. Returns
      # { lines:, more:, clamped:, mid_cut:, saw_any: }.
      #
      # "Is there more file?" is only answered when it can be: the window
      # break proves it by having skipped a line; the budget break proves it
      # by holding a line that didn't fit; at EOF there is none.
      def read_lines(path, offset, limit)
        selected = []
        more = false
        clamped = 0
        mid_cut = false
        output_len = 0
        saw_any = false

        File.foreach(path, chomp: true, invalid: :replace, undef: :replace).with_index do |line, i|
          saw_any = true
          next if i < offset

          if selected.size >= limit
            more = true
            break
          end

          line = line.delete_suffix("\r") # CRLF → LF
          line = Shell.strip_bom(line).last if i.zero? && offset.zero?

          if line.length > @max_line_chars
            line = line[0, @max_line_chars] + "…[clamped at #{@max_line_chars} chars]"
            clamped += 1
          end

          numbered = "#{i + 1}: #{line}"
          cost = numbered.length + 1
          if output_len + cost > @byte_budget
            if selected.empty?
              # One line that outgrows the whole budget: show a slice rather
              # than silence — silence is the most expensive thing a tool can
              # return.
              room = [@byte_budget - output_len - 2, 1].max
              selected << "#{i + 1}: #{line[0, room]}…"
              clamped += 1
              mid_cut = true
            end
            more = true
            break
          end

          output_len += cost
          selected << numbered
        end

        { lines: selected, more: more, clamped: clamped, mid_cut: mid_cut, saw_any: saw_any }
      end

      # ── named recovery: facts, not errors ──────────────────────────────

      def format_output(path, offset, read)
        if read[:lines].empty?
          return read[:saw_any] ?
            ["Offset #{offset} is past the end of the file — retry with a smaller offset.", nil] :
            ["File is empty (0 lines).", nil]
        end

        data = read[:lines].join("\n")
        resume = nil
        if read[:more]
          # A mid-line cut resumes ON the line that was cut (it is the last
          # line shown); every other truncation resumes on the next line.
          resume = read[:mid_cut] ? offset + read[:lines].size - 1 : offset + read[:lines].size
          data << "\n... (more lines) — resume with offset=#{resume}"
        end
        [data, resume]
      end

      def directory_listing(path)
        entries = Dir.children(path).sort
        entries.map! do |e|
          full = File.join(path, e)
          "#{e}#{File.directory?(full) ? '/' : ''}"
        end
        Ask::Result.ok(data: entries.join("\n"), metadata: { type: "directory", count: entries.size })
      end

      # Peek the head of the file: PDF magic first (it's also binary), then
      # a null byte means binary. Returns an Ask::Result for special formats.
      def sniff(path)
        head = File.open(path, "rb") { |f| f.read(1024) } || ""
        if head.start_with?("%PDF")
          return Ask::Result.ok(
            data: "PDF document (#{File.size(path)} bytes) — extract text with pdftotext.",
            metadata: { format: "pdf" }
          )
        end
        if head.include?("\x00")
          mime = MIME_TYPES[File.extname(path).downcase] || "application/octet-stream"
          return Ask::Result.ok(
            data: "Binary file (#{mime}, #{File.size(path)} bytes) — content not shown.",
            metadata: { format: "binary", mime: mime }
          )
        end
        nil
      end

      # ── input repair ───────────────────────────────────────────────────

      # Coerce the value an LLM actually sent into an integer, or return an
      # error message string. Accepts Integer, "2000", 2.0 — rejects "2abc"
      # and 1.5 rather than silently reading a wrong window.
      def coerce_int(name, value)
        case value
        when nil then nil
        when Integer then value
        when String
          value.match?(/\A-?\d+\z/) ? value.to_i : "Invalid #{name}: #{value.inspect} — expected an integer."
        when Float
          value == value.to_i ? value.to_i : "Invalid #{name}: #{value.inspect} — expected an integer."
        else
          "Invalid #{name}: #{value.inspect} — expected an integer."
        end
      end

      # ── device blocklist ───────────────────────────────────────────────

      def device_path?(path)
        DEVICE_PATHS.include?(path) ||
          path.start_with?("/dev/fd/") ||
          path.match?(%r{\A/proc/\d+/fd/}) ||
          path.match?(%r{\A/proc/\d+/task/\d+/fd/})
      end

      # ── filename repair ────────────────────────────────────────────────

      def missing_path_message(path)
        base = File.basename(path)
        dir = File.dirname(path)

        # The model can't see byte-level differences: narrow NBSP vs space,
        # NFD vs NFC, straight vs curly quotes. Retry the candidates for it.
        match = filename_variants(base).find { |c| File.exist?(File.join(dir, c)) }
        if match
          return "Path does not exist: #{path} — a close match exists: " \
                 "#{File.join(dir, match)} (different characters; use that exact path)."
        end

        if File.directory?(dir)
          suggestions = did_you_mean(base, Dir.children(dir))
          unless suggestions.empty?
            return "Path does not exist: #{path} — did you mean: " \
                   "#{suggestions.map { |s| File.join(dir, s) }.join(", ")}?"
          end
        end

        "Path does not exist: #{path}"
      end

      def filename_variants(name)
        variants = []
        [["\u202F", " "], ["\u00A0", " "]].each do |special, plain| # narrow NBSP / NBSP
          variants << name.gsub(special, plain) if name.include?(special)
          variants << name.gsub(plain, special) if name.include?(plain)
        end
        variants << name.unicode_normalize(:nfd) unless name.unicode_normalized?(:nfd)
        variants << name.unicode_normalize(:nfc) unless name.unicode_normalized?(:nfc)
        [["'", "\u2018"], ["'", "\u2019"], ['"', "\u201C"], ['"', "\u201D"]].each do |straight, curly|
          variants << name.gsub(straight, curly) if name.include?(straight)
          variants << name.gsub(curly, straight) if name.include?(curly)
        end
        variants.uniq.reject { |v| v == name }
      end

      def did_you_mean(name, siblings)
        others = siblings.reject { |s| s == name }
        if name.length >= 3
          sub = others.select { |s| s.include?(name) || name.include?(s) }
          return sub.sort_by(&:length).first(3) unless sub.empty?
        end
        others
          .select { |s| levenshtein(name, s) <= 2 }
          .sort_by { |s| levenshtein(name, s) }
          .first(3)
      end

      # Bounded Wagner–Fischer; cheap because we bail on length gap > max.
      def levenshtein(a, b, max: 2)
        return 0 if a == b
        return max + 1 if (a.length - b.length).abs > max

        row = (0..b.length).to_a
        a.each_char do |ac|
          prev = row[0]
          row[0] = prev + 1
          b.each_char.with_index do |bc, j|
            cur = row[j + 1]
            row[j + 1] = [cur + 1, row[j] + 1, prev + (ac == bc ? 0 : 1)].min
            prev = cur
          end
        end
        row[b.length]
      end
    end
  end
end
