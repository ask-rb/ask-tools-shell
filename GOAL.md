# ask-tools-shell — Shell, Filesystem, and Code Execution Tools

## Purpose

Execution tools for agents. Ships Bash, Read, Write, Edit, Glob, Grep, and Code — the tools every agent needs to interact with the filesystem, run shell commands, and execute Ruby code. No agent concepts. No LLM dependencies. Usable standalone in any Ruby script.

## Dependencies

- **Runtime:** `ask-tools` (provides `Ask::Tool` base class, `Ask::Result`)
- **Build/test:** minitest, mocha, rake
- **This gem MUST wait until `ask-tools` is built, tested, and released.** The `Ask::Tool` base class is required.

## Implementation Steps

### 1. Define the gem scaffold
- Create `lib/ask-tools-shell.rb` — entry point, requires all tools
- Create `lib/ask/tools/shell.rb` — module with `.all` that returns all shell tool instances
- Create `lib/ask/tools/shell/version.rb`
- Write `ask-tools-shell.gemspec` depending on `ask-tools`

### 2. Build each tool (one file per tool)

**`Ask::Tools::Bash`** (`lib/ask/tools/shell/bash.rb`)
- Execute shell commands via `Open3.popen3` in a sandboxed temp directory
- Params: `command` (required), `timeout` (default 30s), `workdir` (optional)
- Return `Ask::Result` with stdout, stderr, exit_code, timed_out flag
- Truncate output to 100KB (configurable)
- Kill process on timeout

**`Ask::Tools::Read`** (`lib/ask/tools/shell/read.rb`)
- Read file contents with line numbers, or list directory
- Params: `path` (required), `offset` (optional line offset), `limit` (optional max lines)
- Handle: nonexistent paths, directories, files > 1MB, binary files
- Default limit: 2000 lines

**`Ask::Tools::Write`** (`lib/ask/tools/shell/write.rb`)
- Write content to a file, creating parent directories automatically
- Params: `path` (required), `content` (required)
- Max content size: 500KB (configurable)
- Return path and bytes written

**`Ask::Tools::Edit`** (`lib/ask/tools/shell/edit.rb`)
- Replace exact text in a file
- Params: `path` (required), `old_string` (required), `new_string` (required), `replace_all` (optional boolean)
- Handle: file not found, string not found, files > 1MB

**`Ask::Tools::Glob`** (`lib/ask/tools/shell/glob.rb`)
- Find files matching a glob pattern, sorted by modification time (newest first)
- Params: `pattern` (required), `path` (optional base directory)
- Max results: 1000

**`Ask::Tools::Grep`** (`lib/ask/tools/shell/grep.rb`)
- Search file contents with a regex pattern
- Params: `pattern` (required), `path` (optional directory), `include` (optional file pattern filter)
- Skip: .git, node_modules, vendor, .bundle, tmp, log
- Max matches: 100, max line length: 500 chars

**`Ask::Tools::Code`** (`lib/ask/tools/shell/code.rb`)
- Write and execute Ruby code in a subprocess
- Params: `code` (required, the Ruby source to execute)
- Runs in a temp directory via `Open3.capture3("ruby", script, chdir: Dir.pwd)`
- Passes through environment variables (so `Ask::Auth` env provider works)
- No gem installation — uses gems already available in the environment
- Return stdout, stderr, exit code

### 3. Test coverage (test per tool + integration)
- Each tool gets a dedicated test file: `bash_test.rb`, `read_test.rb`, etc.
- Bash: test stdout, stderr, exit codes, timeout, output truncation
- Read: test file reading, line numbers, offset/limit, directories, large files, missing files
- Write: test file creation, parent dir creation, large content rejection
- Edit: test exact replacement, replace_all, file not found, string not found
- Glob: test pattern matching, result limiting, directory nonexistent
- Grep: test pattern matching, regex errors, directory filtering, result limiting
- Code: test code execution, stdout capture, stderr capture, error handling, env passthrough
- Integration: test `Ask::Tools::Shell.all` returns all tools, each responds to `call`

### 4. README
- Installation
- Each tool documented with params and examples
- Using tools standalone vs with an agent
- Development workflow

### 5. Production hardening
- Sanitize command input for Bash (guard against injection, run in temp dir)
- Handle encoding issues in file reads/writes
- Thread safety in concurrent tool execution
- All file operations use absolute paths (prevent cwd confusion)
- Reasonable resource limits (output size, file size, timeout)

## What "Done" Means

- All 7 tools implemented and passing tests
- `Ask::Tools::Shell.all` returns all 7 tool instances
- Each tool can be used standalone: `Ask::Tools::Bash.new.call(command: "ls")`
- Each tool returns `Ask::Result`
- Bash tools run in sandboxed temp directory
- Code tool executes Ruby and returns output
- >90% test coverage
- README documents every tool with usage examples
