# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/broadcasts endpoints — one-off emails. Stats and click reports are
    # a separate concern, added later.
    class Broadcasts < Base
      # GET /v4/broadcasts
      def list(**params)
        collection("/v4/broadcasts", "broadcasts", Objects::Broadcast, params)
      end

      # GET /v4/broadcasts/:id
      def get(id)
        one(:get, "/v4/broadcasts/#{id}", "broadcast", Objects::Broadcast)
      end

      # POST /v4/broadcasts
      def create(**attributes)
        one(:post, "/v4/broadcasts", "broadcast", Objects::Broadcast, body: attributes)
      end

      # PUT /v4/broadcasts/:id
      def update(id, **attributes)
        one(:put, "/v4/broadcasts/#{id}", "broadcast", Objects::Broadcast, body: attributes)
      end

      # DELETE /v4/broadcasts/:id
      def delete(id)
        http_delete("/v4/broadcasts/#{id}")
        nil
      end
    end
  end
end
