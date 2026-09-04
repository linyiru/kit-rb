# frozen_string_literal: true

module Kit
  module Objects
    # A broadcast (a one-off email) as returned by /v4/broadcasts. `email_template`
    # is a nested {id, name} hash; `subscriber_filter` is the raw filter array;
    # `publication_id` ties a broadcast to its post when it was also published.
    Broadcast = Data.define(
      :id, :publication_id, :created_at, :subject, :preview_text, :description,
      :content, :public, :published_at, :send_at, :thumbnail_alt, :thumbnail_url,
      :public_url, :email_address, :email_template, :subscriber_filter, :status
    ) do
      def self.from(hash)
        new(
          id: hash["id"], publication_id: hash["publication_id"], created_at: hash["created_at"],
          subject: hash["subject"], preview_text: hash["preview_text"], description: hash["description"],
          content: hash["content"], public: hash["public"], published_at: hash["published_at"],
          send_at: hash["send_at"], thumbnail_alt: hash["thumbnail_alt"], thumbnail_url: hash["thumbnail_url"],
          public_url: hash["public_url"], email_address: hash["email_address"],
          email_template: hash["email_template"], subscriber_filter: hash["subscriber_filter"],
          status: hash["status"]
        )
      end
    end
  end
end
