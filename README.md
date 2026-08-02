# ask-tools-shell

[![Gem Version](https://badge.fury.io/rb/ask-tools-shell.svg)](https://badge.fury.io/rb/ask-tools-shell)

Shell, filesystem, and code execution tools for AI agents. Ships 8 tools: Bash, Read, Write, Edit, Glob, Grep, Code, and ApplyPatch. Bash and Code execute through ask-sandbox-providers; the rest operate directly on the local filesystem.

## Installation

```ruby
gem "ask-tools-shell"
```

## Quick Start

```ruby
require "ask-tools-shell"

Ask::Tools::Shell.all.map(&:name)
# => ["bash", "read", "write", "edit", "glob", "grep", "code", "apply_patch"]

result = Ask::Tools::Bash.new.call(command: "echo hello")
result.ok?                 # => true
result.output[:stdout]     # => "hello\n"
result.output[:exit_code]  # => 0
```

## The tools

| Tool | Parameters | Notes |
|---|---|---|
| `Ask::Tools::Bash` | `command`, `timeout` (30), `workdir` | Runs via `Ask::Sandbox.provider`; returns `{ stdout, stderr, exit_code, timed_out }`, output truncated to 100KB |
| `Ask::Tools::Read` | `path`, `offset` (0-indexed), `limit` (2000) | Reads files with line numbers, or lists a directory |
| `Ask::Tools::Write` | `path`, `content` | Creates parent directories automatically |
| `Ask::Tools::Edit` | `path`, `old_string`, `new_string`, `replace_all` | Exact string replacement |
| `Ask::Tools::Glob` | `pattern`, `path` | Up to 1000 files, newest first |
| `Ask::Tools::Grep` | `pattern`, `path`, `include` | Regex search; 100 matches max, skips `.git`, `node_modules`, `vendor`, `.bundle`, `tmp`, `log` |
| `Ask::Tools::Code` | `code` | Runs Ruby via `Ask::Sandbox.provider`; returns `{ stdout, stderr, exit_code }` |
| `Ask::Tools::ApplyPatch` | `patchText` | Applies unified diffs inside a `*** Begin Patch` / `*** End Patch` envelope (Add File, Update File, Delete File sections) |

## Sandboxed execution

`Bash` and `Code` run through `Ask::Sandbox.provider` (ask-sandbox-providers), which defaults to the Local provider. Switch to stronger isolation:

```ruby
Ask::Sandbox.provider = :docker
```

## Full documentation

The full ask-rb documentation lives at https://ask-rb.github.io/ask-docs. [ask-tools in depth](https://ask-rb.github.io/ask-docs/core/tools) covers the shell tools, the ApplyPatch format, and sandbox configuration. API reference: https://ask-rb.github.io/ask-docs/reference/api.

## Development

```
bundle install
bundle exec rake test
```

## License

MIT
