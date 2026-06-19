# Changelog

## 0.3.0 (2026-06-21)

- Added `EditOperations` pluggable interface (read_file, write_file, file_exist?, file?, file_size, expand_path)
- Added `DefaultEditOperations` default implementation
- Added BOM detection/stripping to Edit tool (`Shell.strip_bom`)
- Added line ending detection and preservation to Edit tool (`Shell.detect_line_ending`, `Shell.normalize_line_endings`, `Shell.restore_line_endings`)
- Added `FileMutationQueue` for atomic batch file edits with rollback

## 0.2.2

- Various fixes
