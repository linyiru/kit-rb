# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../../lib", __dir__))
require "kit-rb"

# Live read-only smoke test: hits every read endpoint against the real API and
# reports what came back. Never mutates. Reads KIT_API_KEY from the environment
# or a local .env, so it runs on demand (`rake smoke`), not in CI.
module Kit
  module Smoke
    ENDPOINTS = [
      ["account.get", ->(c) { c.account.get.account.plan_type.inspect }],
      ["subscribers.list", ->(c) { "#{c.subscribers.list.count} on page" }],
      ["tags.list", ->(c) { "#{c.tags.list.count} on page" }],
      ["custom_fields.list", ->(c) { "#{c.custom_fields.list.count} on page" }],
      ["forms.list", ->(c) { "#{c.forms.list.count} on page" }],
      ["sequences.list", ->(c) { "#{c.sequences.list.count} on page" }],
      ["broadcasts.list", ->(c) { "#{c.broadcasts.list.count} on page" }],
      ["email_templates.list", ->(c) { "#{c.email_templates.list.count} on page" }],
      ["segments.list", ->(c) { "#{c.segments.list.count} on page" }],
      ["posts.list", ->(c) { "#{c.posts.list.count} on page" }],
      ["snippets.list", ->(c) { "#{c.snippets.list.count} on page" }]
    ].freeze

    def self.api_key
      return ENV["KIT_API_KEY"] if ENV["KIT_API_KEY"] && !ENV["KIT_API_KEY"].empty?

      env = File.expand_path("../../.env", __dir__)
      File.read(env)[/^KIT_API_KEY=(.+)$/, 1]&.strip if File.exist?(env)
    end

    def self.check(client, name, call)
      puts "  ✓ #{name.ljust(24)} #{call.call(client)}"
      true
    rescue Kit::Error => e
      puts "  ✗ #{name.ljust(24)} #{e.class}: #{e.message}"
      false
    end

    def self.run
      key = api_key
      abort "smoke: set KIT_API_KEY (env or .env) to run the live smoke test" if key.nil? || key.empty?

      client = Kit::Client.new(api_key: key)
      passed = ENDPOINTS.count { |name, call| check(client, name, call) }
      failed = ENDPOINTS.size - passed
      puts(failed.zero? ? "smoke: all #{ENDPOINTS.size} endpoints OK" : "smoke: #{failed} failed")
      abort unless failed.zero?
    end
  end
end
