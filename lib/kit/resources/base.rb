# frozen_string_literal: true

require "erb"

module Kit
  module Resources
    # Shared base for every resource group. Holds the connection and exposes
    # verb helpers under `http_*` names so a resource can define public methods
    # like `get(id)` or `list` without colliding with the transport helpers.
    class Base
      # Default for optional body keywords: "not given", as distinct from nil,
      # which Kit accepts on some fields to clear them (e.g. send_days: nil).
      OMIT = Object.new.freeze

      def initialize(connection)
        @connection = connection
      end

      private

      # Drops the keywords the caller did not pass, keeping explicit nils.
      def given(**attributes)
        attributes.reject { |_, value| value.equal?(OMIT) }
      end

      # Non-enveloped read (whole body) and list reads go through http_get;
      # deletes return no object and go through http_delete. Enveloped
      # single-object and list responses are built by `one` and `collection`.
      def http_get(path, params: {})
        @connection.request(:get, path, params: params)
      end

      # Raw POST/PUT for payloads that are not a single wrapped object — the
      # account colors array, and the bulk endpoints' composite
      # { <resource>, failures } result. Enveloped objects go through `one`.
      def http_post(path, body: nil, params: {})
        @connection.request(:post, path, params: params, body: body)
      end

      def http_put(path, body: nil, params: {})
        @connection.request(:put, path, params: params, body: body)
      end

      # Bulk deletes carry a body (the items to remove), so body is accepted.
      def http_delete(path, body: nil, params: {})
        @connection.request(:delete, path, params: params, body: body)
      end

      # Renders an id into a path segment. Kit ids are integers; a String is
      # accepted but percent-encoded so a value like "1/unsubscribe" cannot
      # rewrite the route, and nil/blank raises before any request is made
      # (a blank id would silently hit the parent list endpoint).
      def path_id(value)
        raise ArgumentError, "id must not be nil or blank" if value.nil? || value.to_s.strip.empty?

        ERB::Util.url_encode(value.to_s)
      end

      # Sends one request that returns a single wrapped object and builds it.
      # `key` is the envelope key (e.g. "subscriber"), `klass` the object built
      # via `klass.from`. Centralised so a resource never hand-writes the read/
      # build/return plumbing — it declares only verb, path, key, class, body.
      def one(verb, path, key, klass, body: nil, params: {})
        response = @connection.request(verb, path, params: params, body: body)
        klass.from(extract(response, key, as: Hash))
      end

      # Fetches a cursor-paginated list and wraps it in a Collection whose next
      # page follows end_cursor. `key` is the array key in the envelope (e.g.
      # "subscribers"), `klass` the object built from each element. Centralised
      # here so every list resource paginates identically and correctly.
      #
      # `verb`/`body` default to a GET with no body; the POST-based filter
      # endpoints pass verb: :post with a filter body, still paging by cursor.
      def collection(path, key, klass, params, verb: :get, body: nil)
        response = @connection.request(verb, path, params: params, body: body)
        data = extract(response, key, as: Array).map { |element| klass.from(element) }
        Collection.new(data: data, pagination: Pagination.from(extract(response, "pagination", as: Hash))) do |after|
          collection(path, key, klass, Collection.next_page_params(params, after), verb: verb, body: body)
        end
      end

      # Reads `key` from a 2xx body, raising UnexpectedResponseError (a
      # Kit::Error, so `rescue Kit::Error` still catches it) instead of the bare
      # KeyError/NoMethodError a drifted or non-JSON response would otherwise
      # produce deep inside the resource. With `as:` the value must also be of
      # that class (Hash for an object envelope, Array for a list): a present
      # key holding `null` or a scalar is the same malformed envelope as a
      # missing key and must not reach `klass.from`, where it would surface as
      # a NoMethodError that looks like a bug in the caller.
      def extract(response, key, as: nil)
        unless response.is_a?(Hash) && response.key?(key)
          raise UnexpectedResponseError.new(
            "expected a JSON object with #{key.inspect} in the response, got #{describe(response)}",
            body: response
          )
        end

        value = response.fetch(key)
        return value if as.nil? || value.is_a?(as)

        raise UnexpectedResponseError.new(
          "expected #{key.inspect} in the response to be #{article(as)}, got #{describe_value(value)}",
          body: response
        )
      end

      def describe(response)
        case response
        when Hash then "keys #{response.keys.inspect}"
        when nil then "an empty body"
        else "a #{response.class} body"
        end
      end

      def describe_value(value)
        case value
        when nil then "null"
        when Hash then "an object with keys #{value.keys.inspect}"
        else "#{article(value.class)} (#{value.inspect[0, 60]})"
        end
      end

      def article(klass)
        klass == Array ? "an Array" : "a #{klass}"
      end
    end
  end
end
