# frozen_string_literal: true

require "json"
require_relative "openapi_contract"
require_relative "../../lib/kit/testing/operations"

# Generates lib/kit/testing/fixtures.json — the example responses Kit::Testing
# builds envelopes from — out of Kit::Testing::OPERATIONS and the vendored
# OpenAPI document's own `example` bodies. Run via `rake testing:fixtures`; the
# contract test regenerates in memory and fails when the shipped file differs.
module TestingFixtures
  PATH = File.expand_path("../../lib/kit/testing/fixtures.json", __dir__)

  # { "subscribers_get" => { "verb" => "get", "path" => "/v4/subscribers/{id}",
  #   "key" => "subscriber", "kind" => "object",
  #   "responses" => { "200" => { "subscriber" => {...} } } }, ... }
  def self.generate
    Kit::Testing::OPERATIONS.to_h do |name, (verb, path)|
      operation = OpenAPIContract.document.fetch("paths").fetch(path).fetch(verb.to_s)
      responses = success_examples(operation)
      key, kind = envelope(responses.values.first)
      type = key && Kit::Testing::TYPES.fetch(name, singular(key))
      [name.to_s, { "verb" => verb.to_s, "path" => path, "key" => key, "kind" => kind, "type" => type,
                    "responses" => responses }]
    end
  end

  # "subscribers" => "subscriber"; only the envelope keys Kit uses need to work.
  def self.singular(key)
    key.sub(/ies\z/, "y").sub(/s\z/, "")
  end

  def self.render
    "#{JSON.pretty_generate(generate)}\n"
  end

  def self.write
    File.write(PATH, render)
  end

  # Every 2xx code with its example body (nil for 204), in the spec's order.
  def self.success_examples(operation)
    operation.fetch("responses").select { |code, _| code.start_with?("2") }.to_h do |code, response|
      content = response.dig("content", "application/json")
      example = content && (content["example"] || content.dig("examples", content["examples"]&.keys&.first, "value"))
      [code, example]
    end
  end

  # The envelope a builder's overrides apply to: the single object key
  # ("subscriber"), the array key of a paginated list ("subscribers"), a
  # non-enveloped raw body (the account colors array), or nothing (204).
  def self.envelope(body)
    return [nil, "none"] if body.nil?
    return [nil, "raw"] unless body.is_a?(Hash)

    key = body.key?("pagination") ? list_key(body) : object_key(body)
    kind = if key
             body.key?("pagination") ? "list" : "object"
           else
             "raw"
           end
    [key, kind]
  end

  def self.list_key(body)
    body.find { |k, v| k != "pagination" && v.is_a?(Array) }&.first
  end

  # One object => that key; the account body (user + account) => "account".
  def self.object_key(body)
    objects = body.select { |_, v| v.is_a?(Hash) }.keys
    return objects.first if objects.size == 1

    "account" if body.key?("account") && body.key?("user")
  end
end
