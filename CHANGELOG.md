## [0.5.1] - 2026-08-10

### Fixed
- **Ledger stays consistent after full-context edits.** `Edit` and
  `ApplyPatch` read files in full, so they now record a full read for the
  current state after writing — previously their write left the ledger with
  a stale partial view that could deny a subsequent `Write` even though the
  file had been fully read in between. (`ApplyPatch` gains the same
  post-write record `Edit` had; `Edit`'s record moved to post-write so it
  stays valid for the current file state.)

## [0.5.0] - 2026-08-10

### Added
- **Read tool engineering pass** — reads are the bill for building context,
  so every decision inside `Ask::Tools::Read` is a token-budget decision:
  - **Three ceilings, not one**: the 2000-line window (existing), a byte
    budget (128 KB of output by default, `ASK_TOOLS_SHELL_READ_BYTE_BUDGET`
    to override) for wide files, and a per-line clamp (2000 chars) for
    minified bundles. Truncated reads return ok with a **precomputed resume
    offset** — no pagination arithmetic for the model.
  - **Named recovery, facts not errors**: empty files, past-EOF offsets,
    binary files (mime note, never garbage bytes), and PDFs (pdftotext hint)
    all return ok with a one-line answer instead of an error.
  - **Streaming reads**: `File.foreach` with an early break at the budget —
    a 400 MB log costs one read, not one load. "Is there more file?" is only
    answered when it can be (peek, never guess).
  - **Strict input repair**: `offset`/`limit` accept `"2000"` and `2.0` but
    reject `"2abc"` and `1.5` instead of silently reading the wrong window.
  - **Device blocklist**: `/dev/zero`, `/dev/urandom`, `/dev/stdin`,
    `/dev/fd/*`, `/proc/*/fd/*` refused by name before any I/O — a read can
    never hang on them.
  - **Filename repair**: NFD/NFC, narrow NBSP, and curly-quote variants are
    retried for the model; then "did you mean?" (substring + bounded
    Levenshtein ≤ 2, catches `AGENT.md` → `AGENTS.md`).
  - **Self-expiring dedup**: re-reading the same unchanged (path, mtime,
    size, offset, limit) window returns a one-line "already in context" stub
    — consumed on use, complete reads only, kill-switch
    `ASK_TOOLS_SHELL_READ_NO_CACHE=1`.
  - **Partial-view ledger** (`Ask::Tools::Shell::FileLedger`): Read records
    what it showed; **Write refuses to overwrite a partially-read unchanged
    file** ("re-read the full file first"), and Edit records a full read so
    the invariant can't deadlock. Ledger entries auto-invalidate when the
    file's mtime/size change.
  - **Hygiene**: BOM stripped, CRLF → LF, invalid UTF-8 replaced instead of
    raising (a read never crashes on bytes).

## [0.4.0] - 2026-08-05

### Added
- **`Ask::Tools::Repl`** — evaluate Ruby code in a persistent session (the
  RLM / recursive language model pattern). A long-lived plain-ruby kernel
  subprocess keeps state across calls: locals, `require`s, and defined
  methods survive between evaluations, so the model composes capabilities as
  code against a working environment instead of re-bootstrapping each time.
  - Framed newline-delimited JSON protocol over stdin/stdout with
    request/response id matching; concurrent calls to a session serialize.
  - Per-evaluation timeout kills the session (state is lost, kernel
    respawns fresh on next call); idle sessions recycle after
    `Repl.idle_timeout` (default 300s).
  - Named sessions shared process-wide (`session:` param, default
    `"default"`); `reset: true` discards state; `Repl.close_session` /
    `Repl.close_all` manage lifetimes; `at_exit` cleanup.
  - Sessions are isolated subprocesses — a crash in one session can't take
    others down, and a dead session is respawned transparently with one
    retry.
  - Kernel spawn strips bundler env vars (RUBYOPT, GEM_HOME, etc.) so the
    session is plain ruby and sees globally installed gems — consistent
    with the one-shot `Code` tool.
- Registered `repl` in `Shell::TOOLS` / `Shell.all`.

## [0.3.4] - 2026-06-25

### Fixed
- **apply_chunks** no longer silently skips unmatched hunks — returns error when hunk text not found in file
- **Add File** parser no longer silently drops lines without `+` prefix — collects all lines as content
- **ApplyPatch tool** now emits proper SSE events during streaming (removed early `next` that suppressed `output_item.added` and `function_call_arguments.delta`)

## [0.3.3] - 2026-06-25

### Changed
- FileMutationQueue tests (8 tests, atomic multi-file writes, rollback). Edge case coverage in bash/read/write tools. Infrastructure: rubocop, overcommit, bin/setup, CI matrix, SimpleCov.
# Changelog

## 0.3.0 (2026-06-21)

- Added `EditOperations` pluggable interface (read_file, write_file, file_exist?, file?, file_size, expand_path)
- Added `DefaultEditOperations` default implementation
- Added BOM detection/stripping to Edit tool (`Shell.strip_bom`)
- Added line ending detection and preservation to Edit tool (`Shell.detect_line_ending`, `Shell.normalize_line_endings`, `Shell.restore_line_endings`)
- Added `FileMutationQueue` for atomic batch file edits with rollback

## 0.2.2

- Various fixes
