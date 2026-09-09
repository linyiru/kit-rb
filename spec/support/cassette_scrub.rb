# frozen_string_literal: true

require "json"

# What a recorded body may not carry, and how it is rewritten before VCR
# writes it to disk. Kept out of spec_helper so the rules can be unit-tested
# (spec/support/cassette_scrub_spec.rb) and audited against every committed
# cassette (spec/cassettes_hygiene_spec.rb).
module CassetteScrub
  # An account can expose several distinct emails, so a value-based filter is
  # not enough: rewrite every address.
  EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/
  # The recording account's kit.com subdomain (form embed URLs) identifies a
  # real creator, and the URL's first path segment is the form uid.
  SUBDOMAIN_URL = %r{https://(?!api\.)[a-z0-9-]+\.kit\.com/[a-f0-9]+}
  # JSON-field patterns tolerate whitespace around the colon so a
  # pretty-printed body is scrubbed the same way.
  FROM_NAME = /"from_name"\s*:\s*"(?:[^"\\]|\\.)*"/
  FORM_UID = /"uid"\s*:\s*"[a-f0-9]+"/
  # The account and user ids name the creator in Kit's App Store and support
  # tooling; fixed Integer stand-ins keep the typed objects parsing the same.
  # Other ids are opaque and stay as recorded.
  ACCOUNT_IDS = { "user" => 1, "account" => 2 }.freeze

  def self.body(body)
    return body if body.nil?

    account_ids(
      body.gsub(EMAIL, "<EMAIL>")
          .gsub(SUBDOMAIN_URL, "https://<SUBDOMAIN>.kit.com/<FORM_UID>")
          .gsub(FROM_NAME, '"from_name":"<FROM_NAME>"')
          .gsub(FORM_UID, '"uid":"<FORM_UID>"')
    )
  end

  # Rewrites user.id / account.id on the parsed JSON, so key order does not
  # matter; a body that is not a JSON object is returned unchanged.
  def self.account_ids(body)
    json = JSON.parse(body)
    return body unless json.is_a?(Hash)

    ACCOUNT_IDS.each { |key, stand_in| json[key]["id"] = stand_in if json[key].is_a?(Hash) && json[key].key?("id") }
    JSON.generate(json)
  rescue JSON::ParserError
    body
  end
end
