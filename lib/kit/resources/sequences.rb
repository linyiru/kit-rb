# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/sequences endpoints. Sequences (formerly "courses"), their
    # subscribers, and the emails that make up each sequence.
    class Sequences < Base
      # GET /v4/sequences
      def list(**params)
        collection("/v4/sequences", "sequences", Objects::Sequence, params)
      end

      # GET /v4/sequences/:id — pass include: "stats" to embed the sequence's
      # performance stats.
      def get(id, include: nil)
        one(:get, "/v4/sequences/#{path_id(id)}", "sequence", Objects::Sequence, params: { include: include }.compact)
      end

      # GET /v4/sequences/:sequence_id/subscribers
      def subscribers(sequence_id, **params)
        collection("/v4/sequences/#{path_id(sequence_id)}/subscribers", "subscribers", Objects::Subscriber, params)
      end

      # POST /v4/sequences
      def create(name:, **attributes)
        one(:post, "/v4/sequences", "sequence", Objects::Sequence, body: { name: name }.merge(attributes))
      end

      # PUT /v4/sequences/:id
      def update(id, **attributes)
        one(:put, "/v4/sequences/#{path_id(id)}", "sequence", Objects::Sequence, body: attributes)
      end

      # DELETE /v4/sequences/:id
      def delete(id)
        http_delete("/v4/sequences/#{path_id(id)}")
        nil
      end

      # POST /v4/sequences/:sequence_id/subscribers/:subscriber_id
      def add_subscriber(sequence_id, subscriber_id)
        one(:post, "/v4/sequences/#{path_id(sequence_id)}/subscribers/#{path_id(subscriber_id)}", "subscriber", Objects::Subscriber)
      end

      # POST /v4/sequences/:sequence_id/subscribers
      def add_subscriber_by_email(sequence_id, email_address:)
        one(:post, "/v4/sequences/#{path_id(sequence_id)}/subscribers", "subscriber", Objects::Subscriber,
            body: { email_address: email_address })
      end

      # GET /v4/sequences/:sequence_id/emails
      def emails(sequence_id, **params)
        collection("/v4/sequences/#{path_id(sequence_id)}/emails", "emails", Objects::SequenceEmail, params)
      end

      # GET /v4/sequences/:sequence_id/emails/:id — include: "stats" embeds the
      # email's performance stats.
      def email(sequence_id, id, include: nil)
        one(:get, "/v4/sequences/#{path_id(sequence_id)}/emails/#{path_id(id)}", "email", Objects::SequenceEmail,
            params: { include: include }.compact)
      end

      # POST /v4/sequences/:sequence_id/emails — subject/delay_value/delay_unit
      # are required; content/position/send_days and the rest are optional.
      def create_email(sequence_id, **attributes)
        one(:post, "/v4/sequences/#{path_id(sequence_id)}/emails", "email", Objects::SequenceEmail, body: attributes)
      end

      # PUT /v4/sequences/:sequence_id/emails/:id
      def update_email(sequence_id, id, **attributes)
        one(:put, "/v4/sequences/#{path_id(sequence_id)}/emails/#{path_id(id)}", "email", Objects::SequenceEmail,
            body: attributes)
      end

      # DELETE /v4/sequences/:sequence_id/emails/:id
      def delete_email(sequence_id, id)
        http_delete("/v4/sequences/#{path_id(sequence_id)}/emails/#{path_id(id)}")
        nil
      end
    end
  end
end
