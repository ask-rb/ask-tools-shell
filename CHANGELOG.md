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
