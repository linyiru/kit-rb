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
  def self.body(body)
    return body if body.nil?

    body.gsub(EMAIL, "<EMAIL>")
        .gsub(SUBDOMAIN_URL, "https://<SUBDOMAIN>.kit.com/<FORM_UID>")
        .gsub(FROM_NAME, '"from_name":"<FROM_NAME>"')
        .gsub(FORM_UID, '"uid":"<FORM_UID>"')
  end
end
