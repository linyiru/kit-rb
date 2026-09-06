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

      # POST /v4/sequences. `send_days` is an array of weekday names,
      # `send_hour` 0–23, `time_zone` an IANA name; `exclude_subscriber_sources`
      # is [{ type: "tag"|"sequence"|"form"|"segment", ids: [...] }].
      def create(name:, email_address: OMIT, email_template_id: OMIT, send_days: OMIT, send_hour: OMIT,
                 time_zone: OMIT, active: OMIT, repeat: OMIT, hold: OMIT, exclude_subscriber_sources: OMIT)
        body = given(name: name, email_address: email_address, email_template_id: email_template_id,
                     send_days: send_days, send_hour: send_hour, time_zone: time_zone, active: active,
                     repeat: repeat, hold: hold, exclude_subscriber_sources: exclude_subscriber_sources)
        one(:post, "/v4/sequences", "sequence", Objects::Sequence, body: body)
      end

      # PUT /v4/sequences/:id — same fields as #create; only those passed change.
      def update(id, name: OMIT, email_address: OMIT, email_template_id: OMIT, send_days: OMIT, send_hour: OMIT,
                 time_zone: OMIT, active: OMIT, repeat: OMIT, hold: OMIT, exclude_subscriber_sources: OMIT)
        body = given(name: name, email_address: email_address, email_template_id: email_template_id,
                     send_days: send_days, send_hour: send_hour, time_zone: time_zone, active: active,
                     repeat: repeat, hold: hold, exclude_subscriber_sources: exclude_subscriber_sources)
        one(:put, "/v4/sequences/#{path_id(id)}", "sequence", Objects::Sequence, body: body)
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

      # POST /v4/sequences/:sequence_id/emails. `delay_unit` is "days" or
      # "hours"; `send_days` nil resets to all seven days; `position` is
      # zero-based and defaults to last.
      def create_email(sequence_id, subject:, delay_value:, delay_unit:, preview_text: OMIT, content: OMIT,
                       email_template_id: OMIT, published: OMIT, send_days: OMIT, position: OMIT)
        body = given(subject: subject, delay_value: delay_value, delay_unit: delay_unit, preview_text: preview_text,
                     content: content, email_template_id: email_template_id, published: published,
                     send_days: send_days, position: position)
        one(:post, "/v4/sequences/#{path_id(sequence_id)}/emails", "email", Objects::SequenceEmail, body: body)
      end

      # PUT /v4/sequences/:sequence_id/emails/:id — only the fields passed
      # change; pass nil for email_template_id or send_days to clear them.
      def update_email(sequence_id, id, subject: OMIT, delay_value: OMIT, delay_unit: OMIT, preview_text: OMIT,
                       content: OMIT, email_template_id: OMIT, published: OMIT, send_days: OMIT, position: OMIT)
        body = given(subject: subject, delay_value: delay_value, delay_unit: delay_unit, preview_text: preview_text,
                     content: content, email_template_id: email_template_id, published: published,
                     send_days: send_days, position: position)
        one(:put, "/v4/sequences/#{path_id(sequence_id)}/emails/#{path_id(id)}", "email", Objects::SequenceEmail,
            body: body)
      end

      # DELETE /v4/sequences/:sequence_id/emails/:id
      def delete_email(sequence_id, id)
        http_delete("/v4/sequences/#{path_id(sequence_id)}/emails/#{path_id(id)}")
        nil
      end
    end
  end
end
