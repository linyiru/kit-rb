# frozen_string_literal: true

module Kit
  module Resources
    # Shared base for every resource group. Holds the connection and exposes
    # verb helpers under `http_*` names so a resource can define public methods
    # like `get(id)` or `list` without colliding with the transport helpers.
    class Base
      def initialize(connection)
        @connection = connection
      end

      private

      # Non-enveloped read (whole body) and list reads go through http_get;
      # deletes return no object and go through http_delete. Enveloped
      # single-object and list responses are built by `one` and `collection`.
      def http_get(path, params: {})
        @connection.request(:get, path, params: params)
      end

      def http_delete(path, params: {})
        @connection.request(:delete, path, params: params)
      end

      # Sends one request that returns a single wrapped object and builds it.
      # `key` is the envelope key (e.g. "subscriber"), `klass` the object built
      # via `klass.from`. Centralised so a resource never hand-writes the read/
      # build/return plumbing — it declares only verb, path, key, class, body.
      def one(verb, path, key, klass, body: nil, params: {})
        response = @connection.request(verb, path, params: params, body: body)
        klass.from(response.fetch(key))
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
        data = response.fetch(key).map { |element| klass.from(element) }
        Collection.new(data: data, pagination: Pagination.from(response.fetch("pagination"))) do |after|
          collection(path, key, klass, params.merge(after: after), verb: verb, body: body)
        end
      end
    end
  end
end
