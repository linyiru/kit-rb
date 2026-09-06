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

      BROADCAST_FIELDS = %i[
        subject preview_text content description public published_at send_at
        email_address email_template_id thumbnail_alt thumbnail_url subscriber_filter
      ].freeze

      # POST /v4/broadcasts. `subscriber_filter` is an array of one group
      # ({ all: | any: | none: [{ type: "segment"|"tag", ids: [...] }] }); omit
      # it to send to every subscriber. Timestamps are ISO 8601 (UTC assumed).
      def create(subject: OMIT, preview_text: OMIT, content: OMIT, description: OMIT, public: OMIT,
                 published_at: OMIT, send_at: OMIT, email_address: OMIT, email_template_id: OMIT,
                 thumbnail_alt: OMIT, thumbnail_url: OMIT, subscriber_filter: OMIT)
        body = given(subject: subject, preview_text: preview_text, content: content, description: description,
                     public: public, published_at: published_at, send_at: send_at, email_address: email_address,
                     email_template_id: email_template_id, thumbnail_alt: thumbnail_alt,
                     thumbnail_url: thumbnail_url, subscriber_filter: subscriber_filter)
        one(:post, "/v4/broadcasts", "broadcast", Objects::Broadcast, body: body)
      end

      # PUT /v4/broadcasts/:id — same fields as #create; only those passed change.
      def update(id, subject: OMIT, preview_text: OMIT, content: OMIT, description: OMIT, public: OMIT,
                 published_at: OMIT, send_at: OMIT, email_address: OMIT, email_template_id: OMIT,
                 thumbnail_alt: OMIT, thumbnail_url: OMIT, subscriber_filter: OMIT)
        body = given(subject: subject, preview_text: preview_text, content: content, description: description,
                     public: public, published_at: published_at, send_at: send_at, email_address: email_address,
                     email_template_id: email_template_id, thumbnail_alt: thumbnail_alt,
                     thumbnail_url: thumbnail_url, subscriber_filter: subscriber_filter)
        one(:put, "/v4/broadcasts/#{path_id(id)}", "broadcast", Objects::Broadcast, body: body)
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
