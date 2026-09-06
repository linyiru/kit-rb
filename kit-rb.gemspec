# frozen_string_literal: true

require_relative "lib/kit/version"

Gem::Specification.new do |spec|
  spec.name = "kit-rb"
  spec.version = Kit::VERSION
  spec.authors = ["Lawrence Lin"]
  spec.email = ["deduce@gmail.com"]

  spec.summary = "A modern, fully-typed Ruby client for the Kit (ConvertKit) API v4."
  spec.description = "kit-rb wraps the Kit v4 REST API with API-key and OAuth 2.0 auth, cursor pagination, typed errors, and immutable value objects."
  spec.homepage = "https://github.com/linyiru/kit-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/linyiru/kit-rb"
  spec.metadata["changelog_uri"] = "https://github.com/linyiru/kit-rb/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/linyiru/kit-rb/issues"
  spec.metadata["documentation_uri"] = "https://github.com/linyiru/kit-rb#readme"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Ship what git tracks, minus development-only files. sig/ is included so
  # RBS consumers get the signatures.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "http", ">= 5.2", "< 7.0"
end
