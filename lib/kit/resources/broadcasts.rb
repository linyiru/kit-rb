# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/broadcasts endpoints — one-off emails, plus their stats and link
    # click reports.
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

      # GET /v4/broadcasts/stats — a cursor-paginated list of per-broadcast stats
      # ({ "id", "stats", "subject", "send_at" } hashes), not full broadcasts.
      def stats_list(**params)
        collection("/v4/broadcasts/stats", "broadcasts", Objects::Raw, params)
      end

      # GET /v4/broadcasts/:id/stats — the raw stats hash for one broadcast.
      def stats(id)
        http_get("/v4/broadcasts/#{id}/stats").fetch("broadcast")
      end

      # GET /v4/broadcasts/:id/clicks — the raw link-click report ({ "id",
      # "clicks" => [...] }); accepts pagination params.
      def clicks(id, **params)
        http_get("/v4/broadcasts/#{id}/clicks", params: params).fetch("broadcast")
      end
    end
  end
end
