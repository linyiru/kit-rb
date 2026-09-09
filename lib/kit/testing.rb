# frozen_string_literal: true

require_relative "testing/operations"
require_relative "testing/fixtures"

module Kit
  # Test support for consumers of this gem: `require "kit/testing"` (it is not
  # loaded by `require "kit-rb"`, and depends on no test framework).
  #
  # Every builder starts from Kit's own documented example response for the
  # operation (lib/kit/testing/fixtures.json, generated from the OpenAPI
  # document and kept in step by a contract test), so a consumer spec reads as
  # "the upsert succeeds" instead of a hand-written envelope that drifts when
  # Kit changes a field:
  #
  #   Kit::Testing.subscriber_json(id: 500, email_address: "ada@example.com")
  #   # => { "subscriber" => { "id" => 500, "email_address" => "ada@example.com", "state" => "active", ... } }
  #
  #   Kit::Testing.response(:tags_create, http_status: 201, name: "vip")   # any operation, by name
  #   Kit::Testing.list_json(:tags_list, [{ name: "vip" }, { name: "beta" }], has_next_page: true)
  #   Kit::Testing.error_json("The API key is invalid")               # => { "errors" => [...] }
  #
  #   Kit::Testing.subscriber(id: 500)                                # typed Kit::Objects::Subscriber
  #   Kit::Testing.account_info(plan_type: "free")                    # Kit::Objects::AccountInfo
  #   Kit::Testing.oauth_token(created_at: Time.now.to_i)             # Kit::OAuth::Token
  #
  # Operation names are `<resource>_<method>` after the client method
  # (Kit::Testing::OPERATIONS). Overrides must be fields Kit documents for
  # that response type (Kit::Testing::TYPES) — a typo, or a field of another
  # type that happens to share the envelope key, raises ArgumentError rather
  # than silently building a response the real API would never send.
  module Testing
    FIXTURES_PATH = Fixtures::PATH
    FIXTURES = Fixtures::ALL
    KNOWN_FIELDS = Fixtures::KNOWN_FIELDS

    # The canonical operation behind each `<object>_json` / `<object>` builder.
    OBJECTS = {
      subscriber: :subscribers_get,
      tag: :tags_create,
      custom_field: :custom_fields_create,
      sequence: :sequences_get,
      sequence_email: :sequences_email,
      broadcast: :broadcasts_get,
      broadcast_stats: :broadcasts_stats,
      post: :posts_get,
      snippet: :snippets_get,
      purchase: :purchases_get,
      webhook: :webhooks_create,
      webhook_endpoint: :webhook_endpoints_get,
      creator_profile: :account_creator_profile,
      email_stats: :account_email_stats,
      growth_stats: :account_growth_stats,
      subscriber_stats: :subscribers_stats,
      account: :account_get
    }.freeze

    class << self
      # The documented example body for `operation` at `http_status` (default:
      # the first 2xx Kit documents), with `overrides` applied to its envelope
      # object. For a paginated list the overrides apply to the first item;
      # use #list_json to shape the whole page. (The selector is not called
      # `status:` because `status` is a documented field of posts, purchases,
      # broadcasts and webhook endpoints, which must stay overridable.)
      def response(operation, http_status: nil, **overrides)
        fixture = Fixtures.for(operation)
        body = Fixtures.deep_dup(fixture["responses"].fetch(Fixtures.status_for(fixture, http_status)))
        apply_overrides!(fixture, body, overrides) unless overrides.empty?
        body
      end

      # The envelope object alone (no wrapper key): what `klass.from` receives.
      def attributes(operation, **overrides)
        fixture = Fixtures.for(operation)
        raise ArgumentError, "#{operation} has no envelope object to build" unless %w[object
                                                                                      list].include?(fixture["kind"])

        value = response(operation, **overrides).fetch(fixture["key"])
        fixture["kind"] == "list" ? value.first : value
      end

      # A cursor-paginated page for a list operation. `items` is an Array of
      # override Hashes (each merged over the documented example item) or an
      # Integer count of example items; pagination fields are keywords.
      def list_json(operation, items = 1, **pagination)
        fixture = Fixtures.for(operation)
        raise ArgumentError, "#{operation} is not a paginated list" unless fixture["kind"] == "list"

        body = Fixtures.deep_dup(fixture["responses"].values.first)
        rows = list_rows(fixture["type"], attributes(operation), items)
        body[fixture["key"]] = rows
        body["pagination"] = pagination_json(body["pagination"], **page_fields(rows, pagination))
        body
      end

      PAGINATION_FIELDS = %i[has_next_page has_previous_page start_cursor end_cursor per_page total_count].freeze

      # A pagination object: `example` (default: the tags list's) with exactly
      # the given fields replaced — an omitted keyword keeps the example's
      # value, an explicit nil clears a cursor. list_json passes the terminal-
      # page defaults itself.
      def pagination_json(example = Fixtures.for(:tags_list)["responses"]["200"]["pagination"], **fields)
        unknown = fields.keys - PAGINATION_FIELDS
        if unknown.any?
          raise ArgumentError, "unknown pagination field(s) #{unknown.inspect}; known: #{PAGINATION_FIELDS.join(", ")}"
        end

        page = example.dup
        fields.each { |field, value| page[field.to_s] = value }
        Fixtures.deep_dup(page) # neither the frozen example's strings nor the caller's own values
      end

      # The error envelope Kit sends on every non-2xx: { "errors" => [...] }.
      def error_json(*messages) = { "errors" => Fixtures.deep_dup(messages.flatten) }

      # The HTTP status a builder defaults to for `operation` (or validates).
      def http_status(operation, http_status = nil) = Fixtures.status_for(Fixtures.for(operation), http_status).to_i

      # The [verb, path] Kit::Testing::OPERATIONS declares for `operation`
      # (a frozen tuple; the registry cannot be altered through it).
      def operation(name)
        Fixtures.for(name) # validates the name with the same message
        OPERATIONS.fetch(name.to_sym)
      end

      private

      # list_json's page is a single terminal page unless told otherwise, and an
      # empty page has no cursors, as the real API answers; keywords still win.
      def page_fields(rows, pagination)
        defaults = { has_next_page: false, has_previous_page: false }
        defaults.merge!(start_cursor: nil, end_cursor: nil) if rows.empty?
        defaults.merge(pagination)
      end

      # Rows for a page: n deep copies of the example with distinct ids (kept
      # in the example's own type — subscribers_filter documents string ids),
      # or each given override Hash merged over its own deep copy, so mutating
      # one row's nested Hash never changes a sibling.
      def list_rows(type, example, items)
        unless items.is_a?(Integer)
          return items.map do |row|
            Fixtures.merge_fields(type, Fixtures.deep_dup(example), row)
          end
        end

        Array.new(items) do |i|
          row = Fixtures.deep_dup(example)
          row["id"] = successor_id(example["id"], i) if example.key?("id")
          row
        end
      end

      def successor_id(id, offset)
        case id
        when Integer then id + offset
        when String then (id.to_i + offset).to_s
        else id
        end
      end

      def apply_overrides!(fixture, body, overrides)
        key = fixture["key"]
        type = fixture["type"]
        case fixture["kind"]
        when "object" then body[key] = Fixtures.merge_fields(type, body[key], overrides)
        when "list" then body[key][0] = Fixtures.merge_fields(type, body[key][0], overrides)
        else raise ArgumentError, "#{fixture["verb"].upcase} #{fixture["path"]} has no envelope object to override"
        end
      end
    end

    # Kit::Testing.subscriber_json(id: 1) etc., one per OBJECTS entry: the
    # canonical operation's response with overrides on its envelope object.
    OBJECTS.each do |object, operation|
      define_singleton_method(:"#{object}_json") { |**overrides| response(operation, **overrides) }
    end
  end
end

require_relative "testing/factories"
