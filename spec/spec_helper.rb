# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  enable_coverage :branch
  add_filter "/spec/"
  minimum_coverage line: 90, branch: 90
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
  # OAuth app credentials, if present, must never reach a committed cassette.
  { "KIT_OAUTH_CLIENT_ID" => "<OAUTH_CLIENT_ID>",
    "KIT_OAUTH_CLIENT_SECRET" => "<OAUTH_CLIENT_SECRET>" }.each do |var, placeholder|
    value = ENV.fetch(var, nil)
    c.filter_sensitive_data(placeholder) { value } if value && !value.empty?
  end
  # Scrub any minted access_token wherever it appears (token response + Bearer).
  c.filter_sensitive_data("<OAUTH_ACCESS_TOKEN>") do |interaction|
    body = interaction.response.body
    body[/"access_token"\s*:\s*"([^"]+)"/, 1] if body
  end
  c.filter_sensitive_data("Bearer <OAUTH_TOKEN>") do |interaction|
    interaction.request.headers["Authorization"]&.first
  end
  # Scrub every email address from recorded request and response bodies — an
  # account can expose several distinct emails, so a value-based filter is not
  # enough; rewrite them all at record time.
  email_pattern = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
  c.before_record do |interaction|
    interaction.response.body = interaction.response.body&.gsub(email_pattern, "<EMAIL>")
    interaction.request.body = interaction.request.body&.gsub(email_pattern, "<EMAIL>")
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
