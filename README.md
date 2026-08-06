# ask-tools-shell

[![Gem Version](https://badge.fury.io/rb/ask-tools-shell.svg)](https://badge.fury.io/rb/ask-tools-shell)

Shell, filesystem, and code execution tools for AI agents. Ships 9 tools: Bash, Read, Write, Edit, Glob, Grep, Code, Repl, and ApplyPatch. Bash and Code execute through ask-sandbox-providers; Repl runs a persistent plain-ruby kernel; the rest operate directly on the local filesystem.

## Installation

```ruby
gem "ask-tools-shell"
```

## Quick Start

```ruby
require "ask-tools-shell"

Ask::Tools::Shell.all.map(&:name)
# => ["bash", "read", "write", "edit", "glob", "grep", "code", "repl", "apply_patch"]

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
| `Ask::Tools::Repl` | `code`, `session`, `reset` | Evaluates Ruby in a persistent session — state (variables, requires, methods) survives across calls; timeouts kill the session and respawn fresh |
| `Ask::Tools::ApplyPatch` | `patchText` | Applies unified diffs inside a `*** Begin Patch` / `*** End Patch` envelope (Add File, Update File, Delete File sections) |

## Sandboxed execution

`Bash` and `Code` run through `Ask::Sandbox.provider` (ask-sandbox-providers), which defaults to the Local provider. Switch to stronger isolation:

```ruby
Ask::Sandbox.provider = :docker
```

`Repl` is a durable control environment (a persistent subprocess that must
keep state) and is not sandboxed — don't point it at untrusted code.

### Code vs Repl

`Code` runs one Ruby snippet in a sandboxed subprocess and forgets it.
`Repl` keeps a session alive so variables and methods survive across calls.

Use `Code` for isolated one-off snippets and for code you don't trust (the
sandbox is the safety boundary). Use `Repl` for multi-step work: load data
and define helpers once, then keep working with them.

## Full documentation

The full ask-rb documentation lives at https://ask-rb.github.io/ask-docs. [ask-tools in depth](https://ask-rb.github.io/ask-docs/core/tools) covers the shell tools, the ApplyPatch format, and sandbox configuration. API reference: https://ask-rb.github.io/ask-docs/reference/api.

## Development

```
bundle install
bundle exec rake test
```

## License

MIT
