# ask-tools-shell

Shell, filesystem, and code execution tools for AI agents. Part of the ask-rb ecosystem.

Provides: **Bash**, **Read**, **Write**, **Edit**, **Glob**, **Grep**, **Code** — the execution tools every agent needs.

## Installation

```ruby
gem "ask-tools-shell"
```

## Usage

```ruby
# Filesystem tools
Ask::Tools::Bash.new.call(command: "ls -la")
Ask::Tools::Read.new.call(path: "/etc/hosts")
Ask::Tools::Grep.new.call(pattern: "TODO", path: ".")

# Ruby code execution — the universal escape hatch
Ask::Tools::Code.new.call(code: <<~RUBY)
  client = Ask::GitHub.client
  client.create_issue("rails/rails", "Bug report", "Details...")
RUBY
```

## Development

```bash
bin/setup
bundle exec rake test
```

## License

MIT
