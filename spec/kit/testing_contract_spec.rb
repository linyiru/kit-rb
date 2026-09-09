# frozen_string_literal: true

require "kit/testing/fixtures"
require_relative "../support/testing_fixtures"

# Kit::Testing is only as good as its fixtures, so these pin them to the
# contract: the operation registry must name every OpenAPI operation exactly
# once, the shipped fixtures.json must be what the generator produces from the
# vendored document today, and every field a builder will accept must be one
# the document declares for that envelope.
RSpec.describe "Kit::Testing contract" do
  let(:document) { OpenAPIContract.document }

  it "registers every OpenAPI operation exactly once, and nothing else" do
    documented = document.fetch("paths").flat_map do |path, verbs|
      verbs.keys.select { |v| %w[get post put patch delete].include?(v) }.map { |v| [v.to_sym, path] }
    end
    registered = Kit::Testing::OPERATIONS.values

    expect(registered).to match_array(documented)
    expect(registered.uniq.size).to eq(registered.size)
  end

  it "ships fixtures.json exactly as `rake testing:fixtures` would generate it today" do
    expect(File.read(Kit::Testing::Fixtures::PATH)).to eq(TestingFixtures.render),
                                                       "fixtures.json is stale: run `bundle exec rake testing:fixtures`"
  end

  it "derives each fixture's envelope key from the schema, not just the example" do
    Kit::Testing::Fixtures::ALL.each do |name, fixture|
      next unless %w[object list].include?(fixture["kind"])

      verb, path = Kit::Testing::OPERATIONS.fetch(name.to_sym)
      code = fixture["responses"].keys.first
      props = document.dig("paths", path, verb.to_s, "responses", code, "content", "application/json", "schema",
                           "properties")
      expected_type = fixture["kind"] == "list" ? "array" : "object"
      expect(props.dig(fixture["key"], "type")).to eq(expected_type),
                                                   "#{name}: #{fixture["key"]} is not a schema #{expected_type}"
    end
  end

  it "accepts only fields the document declares for each response type" do
    Kit::Testing::Fixtures::KNOWN_FIELDS.each do |type, fields|
      declared = Kit::Testing::Fixtures::ALL.each_value.select { |f| f["type"] == type }.flat_map do |f|
        verb, path, key = f.values_at("verb", "path", "key")
        document.dig("paths", path, verb, "responses").select { |c, _| c.start_with?("2") }.flat_map do |_, response|
          props = response.dig("content", "application/json", "schema", "properties", key)
          props = props["items"] if props && props["type"] == "array"
          (props && props["properties"])&.keys || []
        end
      end
      undeclared = fields - declared
      # Kit's examples occasionally carry a field the schema omits; that is a
      # contract gap worth knowing about, so list them here explicitly.
      expect(undeclared).to be_empty, "#{type}: example fields not in schema: #{undeclared.to_a.sort.join(", ")}"
    end
  end

  # The gem's own contract registries already say which Kit::Objects class each
  # operation's envelope becomes. A fixture's `type` must agree with that: the
  # type name is the object's snake_cased class name, so a type that mixed two
  # objects (email vs growth stats, Broadcast vs BroadcastStats) is caught by
  # the parser mapping, not inferred from overlapping field names.
  it "assigns each operation the response type of the object its resource parses" do
    require_relative "contract_spec"
    require_relative "contract_objects_spec"

    expected = {}
    ContractRegistry::LISTS.each { |row| expected[[:get, row[:spec_path]]] = row[:klass] }
    ObjectContractRegistry::OBJECTS.each { |row| expected[[row.verb, row.spec_path]] = row.klass if row.klass }

    checked = 0
    Kit::Testing::Fixtures::ALL.each do |name, fixture|
      klass = expected[Kit::Testing::OPERATIONS.fetch(name.to_sym)]
      next unless klass && fixture["type"]

      snake = klass.name.split("::").last.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      expect(fixture["type"]).to eq(snake), "#{name}: type #{fixture["type"].inspect} but the resource parses #{klass}"
      checked += 1
    end
    expect(checked).to be > 50 # the registries cover most operations; guard against the check going quiet
  end

  it "names every TYPES override for an operation that exists" do
    expect(Kit::Testing::TYPES.keys - Kit::Testing::OPERATIONS.keys).to be_empty
  end
end
