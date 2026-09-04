# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/forms endpoints. Forms themselves are created in the Kit UI, so
    # this resource lists them and manages their subscribers.
    class Forms < Base
      # GET /v4/forms
      def list(**params)
        collection("/v4/forms", "forms", Objects::Form, params)
      end

      # GET /v4/forms/:form_id/subscribers
      def subscribers(form_id, **params)
        collection("/v4/forms/#{form_id}/subscribers", "subscribers", Objects::Subscriber, params)
      end

      # POST /v4/forms/:form_id/subscribers/:subscriber_id
      def add_subscriber(form_id, subscriber_id, referrer: nil)
        object = http_post("/v4/forms/#{form_id}/subscribers/#{subscriber_id}",
                           body: { referrer: referrer }.compact).fetch("subscriber")
        Objects::Subscriber.from(object)
      end

      # POST /v4/forms/:form_id/subscribers
      def add_subscriber_by_email(form_id, email_address:, referrer: nil)
        object = http_post("/v4/forms/#{form_id}/subscribers",
                           body: { email_address: email_address, referrer: referrer }.compact).fetch("subscriber")
        Objects::Subscriber.from(object)
      end
    end
  end
end
