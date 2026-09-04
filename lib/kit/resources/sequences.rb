# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/sequences endpoints. Sequences (formerly "courses") plus their
    # subscribers. Sequence emails are a separate resource.
    class Sequences < Base
      # GET /v4/sequences
      def list(**params)
        collection("/v4/sequences", "sequences", Objects::Sequence, params)
      end

      # GET /v4/sequences/:id
      def get(id)
        one(:get, "/v4/sequences/#{id}", "sequence", Objects::Sequence)
      end

      # GET /v4/sequences/:sequence_id/subscribers
      def subscribers(sequence_id, **params)
        collection("/v4/sequences/#{sequence_id}/subscribers", "subscribers", Objects::Subscriber, params)
      end

      # POST /v4/sequences
      def create(name:, **attributes)
        one(:post, "/v4/sequences", "sequence", Objects::Sequence, body: { name: name }.merge(attributes))
      end

      # PUT /v4/sequences/:id
      def update(id, **attributes)
        one(:put, "/v4/sequences/#{id}", "sequence", Objects::Sequence, body: attributes)
      end

      # DELETE /v4/sequences/:id
      def delete(id)
        http_delete("/v4/sequences/#{id}")
        nil
      end

      # POST /v4/sequences/:sequence_id/subscribers/:subscriber_id
      def add_subscriber(sequence_id, subscriber_id)
        one(:post, "/v4/sequences/#{sequence_id}/subscribers/#{subscriber_id}", "subscriber", Objects::Subscriber)
      end

      # POST /v4/sequences/:sequence_id/subscribers
      def add_subscriber_by_email(sequence_id, email_address:)
        one(:post, "/v4/sequences/#{sequence_id}/subscribers", "subscriber", Objects::Subscriber,
            body: { email_address: email_address })
      end
    end
  end
end
