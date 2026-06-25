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
