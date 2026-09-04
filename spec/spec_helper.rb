# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  minimum_coverage 90
end

require "webmock/rspec"
require "vcr"
require "kit-rb"

require_relative "support/openapi_contract"

WebMock.disable_net_connect!

# VCR records real Kit API interactions into spec/cassettes and replays them.
# Secrets and PII are scrubbed before anything touches disk, so cassettes are
# safe to commit: the API key, OAuth token, and the account email never appear.
VCR.configure do |c|
  c.cassette_library_dir = "spec/cassettes"
  c.hook_into :webmock
  c.configure_rspec_metadata!
  c.default_cassette_options = { record: :once, match_requests_on: %i[method uri] }

  c.filter_sensitive_data("<KIT_API_KEY>") { ENV.fetch("KIT_API_KEY", "test-key") }
  c.filter_sensitive_data("<KIT_API_KEY>") do |interaction|
    interaction.request.headers["X-Kit-Api-Key"]&.first
  end
  c.filter_sensitive_data("Bearer <OAUTH_TOKEN>") do |interaction|
    interaction.request.headers["Authorization"]&.first
  end
  # Scrub the account owner's email from recorded response bodies.
  c.filter_sensitive_data("<EMAIL>") do |interaction|
    body = interaction.response.body
    body[/"email"\s*:\s*"([^"]+)"/, 1] if body
  end
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
end

# Helper: stub a Kit API endpoint with WebMock. Returns the stub for assertions.
def stub_kit(method, path, status: 200, body: {})
  stub_request(method, "https://api.kit.com#{path}")
    .to_return(
      status: status,
      body: body.is_a?(String) ? body : JSON.generate(body),
      headers: { "Content-Type" => "application/json" }
    )
end
