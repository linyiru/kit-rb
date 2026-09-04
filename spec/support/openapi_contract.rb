# frozen_string_literal: true

require "json"

# Loads the vendored Kit API v4 OpenAPI document and derives, from it, the
# authoritative map of every cursor-paginated list endpoint to the envelope key
# under which it returns its array of resources.
#
# This is the "contract" our resources are tested against: a list resource must
# read the exact envelope key the spec declares (e.g. GET /v4/tags returns its
# array under "tags", GET /v4/tags/{tag_id}/subscribers under "subscribers").
# Reading the wrong key is invisible to RuboCop and Steep — the HTTP boundary is
# untyped — so contract_spec.rb pins it against this map instead.
#
# Refresh the vendored document with `rake contract:fetch`.
module OpenAPIContract
  PATH = File.expand_path("kit-v4.openapi.json", __dir__)

  # Source of the vendored document, for `rake contract:fetch` and provenance.
  SOURCE_URL = "https://developers.kit.com/api-reference/v4.json"

  # A GET 200 response whose top-level schema carries a "pagination" object is a
  # cursor-paginated list; its other array property is the resource envelope.
  def self.document
    @document ||= JSON.parse(File.read(PATH))
  end

  # { "/v4/tags" => "tags", "/v4/tags/{tag_id}/subscribers" => "subscribers", ... }
  # keyed by the spec's templated path.
  def self.list_endpoints
    @list_endpoints ||= document.fetch("paths").each_with_object({}) do |(path, ops), map|
      envelope = list_envelope_key(ops)
      map[path] = envelope if envelope
    end
  end

  # The array property of a GET's 200 schema when it is a paginated list, else nil.
  def self.list_envelope_key(operations)
    schema = operations.dig("get", "responses", "200", "content", "application/json", "schema")
    props = schema && schema["properties"]
    return unless props&.key?("pagination")

    props.keys.find { |k| k != "pagination" && props[k]["type"] == "array" }
  end
  private_class_method :list_envelope_key

  # The envelope key the spec declares for a templated list path, or nil.
  def self.envelope_for(templated_path)
    list_endpoints[templated_path]
  end
end
