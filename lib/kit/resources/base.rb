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
    end
  end
end
