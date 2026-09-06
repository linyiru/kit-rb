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

  # { [:get, "/v4/subscribers/{id}"] => "subscriber", ... } — every operation
  # whose 2xx body wraps exactly one object (and is not a paginated list).
  def self.object_endpoints
    @object_endpoints ||= document.fetch("paths").each_with_object({}) do |(path, ops), map|
      ops.each do |verb, operation|
        next unless operation.is_a?(Hash) && operation["responses"]

        key = object_envelope_key(operation)
        map[[verb.to_sym, path]] = key if key
      end
    end
  end

  def self.object_envelope_key(operation)
    _code, response = operation["responses"].find { |code, _| code.start_with?("2") }
    props = response&.dig("content", "application/json", "schema", "properties")
    return if props.nil? || props.key?("pagination")

    objects = props.select { |_, schema| schema["type"] == "object" }
    objects.keys.first if objects.size == 1
  end
  private_class_method :object_envelope_key

  # The top-level property names of an operation's JSON request body (a oneOf
  # is unioned), or nil when the spec declares no body.
  def self.request_body_keys(verb, path)
    schema = document.dig("paths", path, verb.to_s, "requestBody", "content", "application/json", "schema")
    return nil unless schema

    (schema["oneOf"] || [schema]).flat_map { |variant| (variant["properties"] || {}).keys }.uniq
  end

  # True when the spec's success response for the operation is 204 No Content.
  def self.no_content?(verb, path)
    document.dig("paths", path, verb.to_s, "responses")&.key?("204") || false
  end
end
