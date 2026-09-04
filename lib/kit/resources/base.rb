# frozen_string_literal: true

module Kit
  module Resources
    # Shared base for every resource group. Holds the connection and exposes
    # thin verb helpers so resource classes read as `get("/v4/account")`.
    class Base
      def initialize(connection)
        @connection = connection
      end

      private

      def get(path, params: {})
        @connection.request(:get, path, params: params)
      end

      def post(path, body: nil, params: {})
        @connection.request(:post, path, params: params, body: body)
      end

      def put(path, body: nil, params: {})
        @connection.request(:put, path, params: params, body: body)
      end

      def delete(path, params: {})
        @connection.request(:delete, path, params: params)
      end
    end
  end
end
