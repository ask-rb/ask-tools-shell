require_relative "lib/ask/tools/shell/version"

Gem::Specification.new do |spec|
  spec.name = "ask-tools-shell"
  spec.version = Ask::Tools::Shell::VERSION
  spec.authors = ["Kaka Ruto"]
  spec.email = ["kaka@myrrlabs.com"]

  spec.summary = "Shell, filesystem, and code execution tools"
  spec.description = "Bash, Read, Write, Edit, Glob, Grep, and Code tools for the ask-rb ecosystem."
  spec.homepage = "https://github.com/ask-rb/ask-tools-shell"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ask-tools", "~> 0.1"

  spec.add_development_dependency "minitest", "~> 5.25"
  spec.add_development_dependency "mocha", "~> 3.1"
  spec.add_development_dependency "rake", "~> 13.0"
end
