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

      def http_get(path, params: {})
        @connection.request(:get, path, params: params)
      end

      def http_post(path, body: nil, params: {})
        @connection.request(:post, path, params: params, body: body)
      end

      def http_put(path, body: nil, params: {})
        @connection.request(:put, path, params: params, body: body)
      end

      def http_delete(path, params: {})
        @connection.request(:delete, path, params: params)
      end

      # Fetches a cursor-paginated list and wraps it in a Collection whose next
      # page follows end_cursor. `key` is the array key in the envelope (e.g.
      # "subscribers"), `klass` the object built from each element. Centralised
      # here so every list resource paginates identically and correctly.
      def collection(path, key, klass, params)
        body = http_get(path, params: params)
        data = body.fetch(key).map { |element| klass.from(element) }
        Collection.new(data: data, pagination: Pagination.from(body.fetch("pagination"))) do |after|
          collection(path, key, klass, params.merge(after: after))
        end
      end
    end
  end
end
