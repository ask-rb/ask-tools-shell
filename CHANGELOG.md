# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-06-09

### Added

- `Ask::Tools::Bash` — Execute shell commands in a sandboxed temp directory with timeout and output truncation
- `Ask::Tools::Read` — Read file contents with line numbers, offset/limit support, and directory listing
- `Ask::Tools::Write` — Write content to files with automatic parent directory creation
- `Ask::Tools::Edit` — Replace exact text in files (single or all occurrences)
- `Ask::Tools::Glob` — Find files matching glob patterns, sorted by modification time
- `Ask::Tools::Grep` — Search file contents with regex patterns, directory exclusion, and result limiting
- `Ask::Tools::Code` — Execute Ruby code in a subprocess with stdout/stderr capture
- `Ask::Tools::Shell.all` — Collection point returning all 7 tool instances
- Comprehensive test suite: 55 tests covering normal paths, edge cases, and error conditions
