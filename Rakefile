# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Type-check with Steep"
task :steep do
  sh "bundle exec steep check"
end

namespace :contract do
  desc "Refresh the vendored Kit OpenAPI document the contract tests pin against"
  task :fetch do
    require "open-uri"
    require_relative "spec/support/openapi_contract"
    body = URI.parse(OpenAPIContract::SOURCE_URL).read
    File.write(OpenAPIContract::PATH, body)
    puts "Fetched #{OpenAPIContract::SOURCE_URL} -> #{OpenAPIContract::PATH} (#{body.bytesize} bytes)"
  end
end

task default: %i[spec rubocop steep]
