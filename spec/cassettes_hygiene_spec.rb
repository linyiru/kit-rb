# frozen_string_literal: true

require "json"
require "yaml"

# Every committed cassette must already satisfy the before_record scrub rules
# in spec_helper. VCR only scrubs at record time, so a rule added later, or a
# cassette hand-edited, would otherwise leave identifying data in git; this
# fails the suite instead.
RSpec.describe "Committed cassettes" do
  cassettes = Dir[File.expand_path("cassettes/**/*.yml", __dir__)]

  def parse_json(body)
    JSON.parse(body)
  rescue JSON::ParserError
    nil
  end

  it "exists" do
    expect(cassettes).not_to be_empty
  end

  cassettes.each do |path|
    describe File.basename(path) do
      let(:interactions) { YAML.safe_load_file(path, permitted_classes: [Symbol]).fetch("http_interactions") }
      let(:bodies) do
        interactions.flat_map do |i|
          [i.dig("response", "body", "string"), i.dig("request", "body", "string")]
        end.compact
      end
      let(:headers) do
        interactions.flat_map do |i|
          [i.dig("request", "headers"), i.dig("response", "headers")]
        end.compact
      end

      it "carries no credential, cookie or email" do
        headers.each do |header|
          expect(header.keys.map(&:downcase)).not_to include("set-cookie", "cookie")
          expect(header["X-Kit-Api-Key"].to_a).to all(eq("<KIT_API_KEY>"))
          expect(header["Authorization"].to_a).to all(eq("Bearer <OAUTH_ACCESS_TOKEN>"))
        end
        bodies.each do |body|
          expect(body).not_to match(/kit_[a-f0-9]{16,}/)
          expect(body).not_to match(/[A-Za-z0-9._%+-]+@(?!example\.com|convertkit\.dev)[A-Za-z0-9.-]+\.[A-Za-z]{2,}/)
        end
      end

      it "names no creator: no subdomain, sender name, form uid, or account/user id" do
        bodies.each do |body|
          expect(body).not_to match(%r{https://(?!api\.|<SUBDOMAIN>\.)[a-z0-9-]+\.kit\.com/})
          # a scrubbed subdomain must not still carry the real form uid as its first path segment
          body.scan(%r{https://<SUBDOMAIN>\.kit\.com/([^/"]+)}).flatten.each { |segment| expect(segment).to eq("<FORM_UID>") }
          body.scan(/"from_name"\s*:\s*"((?:[^"\\]|\\.)*)"/).flatten.each { |name| expect(name).to eq("<FROM_NAME>") }
          body.scan(/"uid"\s*:\s*"([^"]*)"/).flatten.each { |uid| expect(uid).to eq("<FORM_UID>") }
          json = parse_json(body)
          next unless json.is_a?(Hash)

          expect(json.dig("user", "id")).to eq(1) if json["user"].is_a?(Hash) && json["user"].key?("id")
          expect(json.dig("account", "id")).to eq(2) if json["account"].is_a?(Hash) && json["account"].key?("id")
        end
      end
    end
  end
end
