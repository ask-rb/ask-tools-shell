---
name: shell.patterns
description: Common shell tool composition patterns for code analysis, searching, and file manipulation
---

Use this skill when you need to search, analyze, or manipulate a codebase using
shell tools. These patterns show you the most effective way to combine tools
for common tasks.

## Pattern 1: Find and Search with Glob + Grep

The most powerful pattern for code analysis is combining Glob and Grep.

**Find files of a type, then search their contents:**

```ruby
# Step 1: Find relevant files
result = Glob.new.call(pattern: "**/*.rb", path: "/path/to/project")

# Step 2: Search for a pattern in those files
Grep.new.call(pattern: "class.*API", path: "/path/to/project", include: "*.rb")
```

**Search first to narrow, then read specific files:**

```ruby
# Step 1: Find where a method is used
Grep.new.call(pattern: "def process_payment", path: "/project")

# Step 2: Read the specific files found
Read.new.call(path: "/project/app/services/payment_processor.rb")
```

## Pattern 2: Read Files with Offset/Limit

When reading large files, use offset and limit to navigate:

```ruby
# Read the first 50 lines
Read.new.call(path: "large_file.rb", limit: 50)

# Then read from where you left off
Read.new.call(path: "large_file.rb", offset: 50, limit: 50)
```

This avoids truncation and lets you browse files in chunks.

## Pattern 3: Pipe Shell Commands via Bash

For complex queries that aren't a simple grep, use Bash with pipes:

```ruby
# Count lines of Ruby code
Bash.new.call(command: "find . -name '*.rb' -exec cat {} \\; | wc -l", workdir: "/project")

# Find the top 10 largest files
Bash.new.call(command: "find . -name '*.rb' -exec wc -l {} \\; | sort -rn | head -10", workdir: "/project")

# Search git history
Bash.new.call(command: "git log --oneline --all --grep='fix' | head -20", workdir: "/project")
```

## Pattern 4: Edit with Read + Edit + Read

The safe way to make changes is Read → Edit → Read:

```ruby
# Step 1: Read the file to find exact text
Read.new.call(path: "app/models/user.rb")

# Step 2: Edit with exact match (provide surrounding context for uniqueness)
Edit.new.call(
  path: "app/models/user.rb",
  old_string: "has_many :posts",
  new_string: "has_many :posts, dependent: :destroy"
)

# Step 3: Verify the change
Read.new.call(path: "app/models/user.rb", limit: 30)
```

When a string could appear multiple times:
```ruby
# First verify occurrences
Grep.new.call(pattern: "old_string", path: "/project")

# Then replace all if appropriate
Edit.new.call(path: "file.rb", old_string: "old", new_string: "new", replace_all: true)
```

## Pattern 5: Code Execution for Quick Ruby Checks

Use Code for ad-hoc Ruby that doesn't need tools:

```ruby
# Check Ruby version or gem availability
Code.new.call(code: "puts Gem::Specification.map(&:name).grep(/devise/).first")

# Parse and inspect data structures
Code.new.call(code: "require 'json'; data = JSON.parse(File.read('data.json')); puts data.keys")

# Test a regex before using it in Grep
Code.new.call(code: "puts /foo.*bar/.match?('foo_baz_bar')")
```

## Pattern 6: Write Files with Content

Create or overwrite files with Write:

```ruby
# Create a new file
Write.new.call(path: "/project/app/services/new_service.rb", content: <<~RUBY)
  class NewService
    def call
      # ...
    end
  end
RUBY
```

Write creates parent directories automatically — no need for mkdir -p first.

## Pattern 7: Project Structure Overview

Get a quick lay of the land:

```ruby
# List top-level structure
Read.new.call(path: "/project")

# Count files by type
Bash.new.call(command: "find . -name '*.rb' | sed 's/.*\\.//' | sort | uniq -c | sort -rn", workdir: "/project")

# List all models or controllers
Glob.new.call(pattern: "app/models/**/*.rb", path: "/project")
Glob.new.call(pattern: "app/controllers/**/*.rb", path: "/project")
```

## Pattern 8: Search with Exclusions

To exclude test directories or vendor code:

```ruby
# Grep already excludes .git, node_modules, vendor, .bundle, tmp, log
# For additional exclusions, use Bash:
Bash.new.call(
  command: "grep -rn 'search_term' app/ lib/ --include='*.rb' | grep -v '_spec.rb' | head -50",
  workdir: "/project"
)
```

## Pattern 9: Sequential File Processing

When you need to apply the same pattern across multiple files:

```ruby
# Step 1: Find the files
result = Glob.new.call(pattern: "app/views/**/*.erb", path: "/project")

# Step 2: Search for the pattern you need to understand
Grep.new.call(pattern: "data-controller", path: "/project", include: "*.erb")
```

## Efficiency Guide

| Task | Best Tool | Why |
|------|-----------|-----|
| Find files by name pattern | Glob | Fast, sorted newest first |
| Search file contents | Grep | Pattern-aware, excludes cruft |
| Read small files | Read | Line numbers, truncation-safe |
| Read large files | Read (offset/limit) | Navigate in chunks |
| Complex shell queries | Bash | Full shell power |
| Ad-hoc Ruby checks | Code | Direct Ruby execution |
| Make changes | Edit | Exact string replacement |
| Create files | Write | Mkdir-p + write in one |
