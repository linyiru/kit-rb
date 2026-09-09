# frozen_string_literal: true

require "erb"
require_relative "../errors"

module Kit
  module Testing # rubocop:disable Style/Documentation -- documented in lib/kit/testing.rb
    # WebMock stubs by operation name, so a consumer spec reads as "the upsert
    # succeeds" instead of as a URL, a header hash and a hand-written envelope:
    #
    #   Kit::Testing.stub(:subscribers_create, id: 500)                 # 200 with the documented body
    #   Kit::Testing.stub(:tags_tag_subscriber, tag_id: 7, id: 500)     # path params by name
    #   Kit::Testing.stub(:tags_list, items: [{ name: "vip" }], has_next_page: true)
    #   Kit::Testing.stub_error(:account_get, 401, "The API key is invalid")
    #   Kit::Testing.stub_rate_limited(:subscribers_create, retry_after: 7)
    #
    # Each returns WebMock's request stub, so `.with(...)`, `.to_return(...)`
    # chaining and `expect(stub).to have_been_requested` work as usual. Path
    # params not given match any value; any query string matches. WebMock is
    # not a dependency of this gem: require it in your spec_helper.
    module Stubs
      BASE_URL = "https://api.kit.com"
      JSON_HEADERS = { "Content-Type" => "application/json" }.freeze

      # A successful response for `operation`: the documented example at
      # `http_status:` (default: the first Kit documents) with `overrides` on
      # its envelope object. Path params are given by name (`id:`, `tag_id:`);
      # for a list operation `items:` and the pagination keywords shape the
      # page as #list_json does. A path param that is also a field of the
      # response object (`id:` on subscribers_get) applies to both, so the
      # body answers with the id that was asked for.
      def stub(operation, http_status: nil, **params)
        fixture = Fixtures.for(operation)
        template = operation(operation).last
        path_params = params.select { |key, _| template.include?("{#{key}}") }
        overrides = params.reject { |key, _| path_params.key?(key) && !body_field?(fixture, key) }
        status = Fixtures.status_for(fixture, http_status)
        request_stub(operation, path_params).to_return(status: status.to_i, headers: JSON_HEADERS,
                                                       body: stub_body(operation, fixture, status, overrides))
      end

      # A failing response: Kit's { "errors" => [...] } envelope at `status`.
      def stub_error(operation, status, *messages, **path_params)
        request_stub(operation, path_params)
          .to_return(status: status, headers: JSON_HEADERS, body: JSON.generate(error_json(*messages)))
      end

      # A 429 with `Retry-After` (seconds), as Kit sends it.
      def stub_rate_limited(operation, retry_after: 30, **path_params)
        request_stub(operation, path_params)
          .to_return(status: 429, headers: JSON_HEADERS.merge("Retry-After" => retry_after.to_s),
                     body: JSON.generate(error_json("Rate limit exceeded")))
      end

      # The URL of an operation with its path params filled in: a String when
      # every placeholder is given (for `a_request(verb, url)`), else a Regexp
      # with `[^/?]+` for the rest. Neither admits a query string; stubs do.
      def url_for(operation, **path_params)
        template, given = url_parts(operation, path_params)
        return "#{BASE_URL}#{fill(template, given)}" if complete?(template, given)

        /\A#{Regexp.escape(BASE_URL)}#{path_pattern(template, given)}\z/
      end

      private

      # The template and the given params as encoded path segments — exactly
      # what Resources::Base#path_id sends, so `id: "a b"` matches `/a%20b` and
      # `id: "1/unsubscribe"` cannot rewrite the route; nil/blank raises like
      # the client does instead of collapsing onto the parent route.
      def url_parts(operation, path_params)
        template = operation(operation).last
        unknown = path_params.keys.map(&:to_s) - placeholders(template)
        raise ArgumentError, "#{unknown.first.inspect} is not a path param of #{template}" if unknown.any?

        [template, path_params.to_h { |key, value| [key.to_s, path_segment(key, value)] }]
      end

      def path_segment(key, value)
        raise ArgumentError, "#{key} must not be nil or blank" if value.nil? || value.to_s.strip.empty?

        ERB::Util.url_encode(value.to_s)
      end

      def placeholders(template) = template.scan(/\{(\w+)\}/).flatten
      def complete?(template, given) = (placeholders(template) - given.keys).empty?
      def fill(template, given) = template.gsub(/\{(\w+)\}/) { given.fetch(Regexp.last_match(1)) }

      def path_pattern(template, given)
        Regexp.escape(template).gsub(/\\\{(\w+)\\\}/) do
          given.key?(Regexp.last_match(1)) ? Regexp.escape(given[Regexp.last_match(1)]) : "[^/?]+"
        end
      end

      # Stubs match the path with any query string, since list filters and
      # remove_*_by_email travel there.
      def request_stub(operation, path_params)
        webmock!
        verb, = operation(operation)
        template, given = url_parts(operation, path_params)
        WebMock::API.stub_request(verb, /\A#{Regexp.escape(BASE_URL)}#{path_pattern(template, given)}(\?.*)?\z/)
      end

      # True when `key` is a documented field of the operation's response type
      # (so a same-named path param should also override the body).
      def body_field?(fixture, key)
        type = fixture["type"]
        type && Fixtures::KNOWN_FIELDS[type]&.include?(key.to_s)
      end

      # The body for the selected status: the list page (list operations
      # document one status), the status-specific example (bulk 202s are
      # empty; a 201 may differ from the 200), or nothing for a 204.
      def stub_body(operation, fixture, status, overrides)
        case fixture["kind"]
        when "none" then ""
        when "list" then JSON.generate(list_body(operation, overrides))
        else JSON.generate(response(operation, http_status: status, **overrides))
        end
      end

      # A list page: `items:` (rows or a count), the pagination keywords, and
      # any remaining keys — a same-named path field such as sequence_id — are
      # applied to every row.
      def list_body(operation, overrides)
        items = overrides.fetch(:items, 1)
        pagination = overrides.slice(*PAGINATION_FIELDS)
        row_fields = overrides.except(:items, *PAGINATION_FIELDS)
        rows = items.is_a?(Integer) ? Array.new(items) { |i| { "id" => attributes(operation)["id"].to_i + i } } : items
        # The path is the source of truth for a shared field: it wins over a row.
        rows = rows.map { |row| row.merge(row_fields) } if row_fields.any?
        list_json(operation, rows, **pagination)
      end

      def webmock!
        return if defined?(WebMock::API)

        raise ConfigurationError,
              "Kit::Testing.stub needs WebMock: add `gem \"webmock\"` to your test group and require \"webmock/rspec\""
      end
    end

    extend Stubs
  end
end
