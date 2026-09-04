# frozen_string_literal: true

require_relative "lib/kit/version"

Gem::Specification.new do |spec|
  spec.name = "kit-rb"
  spec.version = Kit::VERSION
  spec.authors = ["Lawrence Lin"]
  spec.email = ["deduce@gmail.com"]

  spec.summary = "A modern, fully-typed Ruby client for the Kit (ConvertKit) API v4."
  spec.description = "kit-rb wraps the Kit v4 REST API with API-key and OAuth 2.0 auth, cursor pagination, typed errors, and immutable value objects."
  spec.homepage = "https://github.com/solcreek/kit-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/solcreek/kit-rb"
  spec.metadata["changelog_uri"] = "https://github.com/solcreek/kit-rb/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Uncomment the line below to require MFA for gem pushes.
  # This helps protect your gem from supply chain attacks by ensuring
  # no one can publish a new version without multi-factor authentication.
  # See: https://guides.rubygems.org/mfa-requirement-opt-in/
  # spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
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

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "http", "~> 5.2"

  # For more information and examples about making a new gem, check out our
  # guide at: https://guides.rubygems.org/make-your-own-gem/
end
