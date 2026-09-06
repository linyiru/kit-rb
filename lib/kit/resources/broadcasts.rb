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
        one(:get, "/v4/broadcasts/#{path_id(id)}", "broadcast", Objects::Broadcast)
      end

      # POST /v4/broadcasts
      def create(**attributes)
        one(:post, "/v4/broadcasts", "broadcast", Objects::Broadcast, body: attributes)
      end

      # PUT /v4/broadcasts/:id
      def update(id, **attributes)
        one(:put, "/v4/broadcasts/#{path_id(id)}", "broadcast", Objects::Broadcast, body: attributes)
      end

      # DELETE /v4/broadcasts/:id
      def delete(id)
        http_delete("/v4/broadcasts/#{path_id(id)}")
        nil
      end

      # GET /v4/broadcasts/stats — a cursor-paginated list of per-broadcast stats.
      def stats_list(**params)
        collection("/v4/broadcasts/stats", "broadcasts", Objects::BroadcastStats, params)
      end

      # GET /v4/broadcasts/:id/stats — one broadcast's performance stats.
      def stats(id)
        one(:get, "/v4/broadcasts/#{path_id(id)}/stats", "broadcast", Objects::BroadcastStats)
      end

      # GET /v4/broadcasts/:id/clicks — a cursor-paginated Collection of the
      # broadcast's clicked links. The API nests the array under "broadcast", so
      # this is built directly rather than through Base#collection.
      def clicks(id, **params)
        body = http_get("/v4/broadcasts/#{path_id(id)}/clicks", params: params)
        rows = extract(extract(body, "broadcast"), "clicks").map { |row| Objects::BroadcastClick.from(row) }
        Collection.new(data: rows, pagination: Pagination.from(extract(body, "pagination"))) do |after|
          clicks(id, **Collection.next_page_params(params, after))
        end
      end
    end
  end
end
