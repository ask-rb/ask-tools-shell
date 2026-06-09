# ask-tools-shell

Shell, filesystem, and code execution tools for AI agents. Part of the ask-rb ecosystem.

Provides **Bash**, **Read**, **Write**, **Edit**, **Glob**, **Grep**, and **Code** — the execution tools every agent needs.

```ruby
gem "ask-tools-shell"
```

## Dependencies

- **ask-tools** ~> 0.1 (provides `Ask::Tool` base class and `Ask::Result`)

---

## Quick Start

```ruby
require "ask-tools-shell"

# List all available tools
Ask::Tools::Shell.all.map(&:name)
# => ["bash", "read", "write", "edit", "glob", "grep", "code"]

# Use a tool standalone
result = Ask::Tools::Bash.new.call(command: "echo hello")
result.ok?              # => true
result.output[:stdout]  # => "hello\n"
result.output[:exit_code] # => 0
```

---

## Tools

### `Ask::Tools::Bash`

Execute shell commands in a sandboxed temp directory.

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `command` | `string` | Yes | — | The bash command to execute |
| `timeout` | `integer` | No | 30 | Timeout in seconds |
| `workdir` | `string` | No | temp dir | Working directory |

Returns `{ stdout, stderr, exit_code, timed_out }`. Output truncated to 100KB. Process killed on timeout.

```ruby
Ask::Tools::Bash.new.call(command: "ls -la", timeout: 10)
```

### `Ask::Tools::Read`

Read file contents with line numbers, or list directory entries.

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `path` | `string` | Yes | — | Absolute path to file or directory |
| `offset` | `integer` | No | 0 | Starting line number (0-indexed) |
| `limit` | `integer` | No | 2000 | Maximum lines to read |

```ruby
Ask::Tools::Read.new.call(path: "/etc/hosts")
Ask::Tools::Read.new.call(path: "large.log", offset: 100, limit: 50)
```

### `Ask::Tools::Write`

Write content to a file. Creates parent directories automatically.

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `path` | `string` | Yes | — | Absolute path to write to |
| `content` | `string` | Yes | — | File content (max 500KB) |

```ruby
Ask::Tools::Write.new.call(path: "/tmp/hello.txt", content: "Hello, World!")
```

### `Ask::Tools::Edit`

Replace exact text in a file. Uses exact string matching.

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `path` | `string` | Yes | — | Absolute path to the file |
| `old_string` | `string` | Yes | — | Exact text to replace |
| `new_string` | `string` | Yes | — | Replacement text |
| `replace_all` | `boolean` | No | false | Replace all occurrences |

```ruby
Ask::Tools::Edit.new.call(path: "file.rb", old_string: "foo", new_string: "bar")
Ask::Tools::Edit.new.call(path: "file.rb", old_string: "x", new_string: "y", replace_all: true)
```

### `Ask::Tools::Glob`

Find files matching a glob pattern, sorted by modification time (newest first).

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `pattern` | `string` | Yes | — | Glob pattern (e.g. `**/*.rb`) |
| `path` | `string` | No | current dir | Base directory |

Max 1000 results.

```ruby
Ask::Tools::Glob.new.call(pattern: "**/*.rb", path: "/path/to/project")
```

### `Ask::Tools::Grep`

Search file contents using a regex pattern.

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `pattern` | `string` | Yes | — | Regex pattern to search for |
| `path` | `string` | No | current dir | Directory to search |
| `include` | `string` | No | `**/*` | File pattern filter (e.g. `*.rb`) |

Max 100 matches. Line content capped at 500 chars. Skips `.git`, `node_modules`, `vendor`, `.bundle`, `tmp`, `log`.

```ruby
Ask::Tools::Grep.new.call(pattern: "TODO", path: ".", include: "*.rb")
```

### `Ask::Tools::Code`

Write and execute Ruby code in a subprocess. Uses gems already available in the environment.

| Param | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `code` | `string` | Yes | — | Ruby source code to execute |

Returns `{ stdout, stderr, exit_code }`. Output truncated to 100KB.

```ruby
Ask::Tools::Code.new.call(code: <<~RUBY)
  puts "Hello from Ruby!"
  result = 2 + 2
  puts "2 + 2 = #{result}"
RUBY
```

---

## Using Tools with an Agent

```ruby
require "ask-tools-shell"

# All tools
tools = Ask::Tools::Shell.all

# Find by name
bash = Ask::Tools["bash"]
bash.call(command: "date")
```

---

## Development

```bash
bundle install
bundle exec rake test
gem build ask-tools-shell.gemspec
```

## License

MIT
