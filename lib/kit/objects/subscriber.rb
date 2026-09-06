# frozen_string_literal: true

module Kit
  module Objects
    # A subscriber as returned by /v4/subscribers. `fields` holds custom-field
    # values; `location` is present on some responses; both are plain Hashes.
    #
    # Context fields, nil unless the endpoint supplies them:
    # - `added_at`, `referrer`, `referrer_utm_parameters` — form/sequence
    #   subscriber lists (when this subscriber joined through that form/sequence)
    # - `tagged_at` — a tag's subscriber list
    # - `attribution`, `tags` — list reads made with include: "attribution,tags"
    # - `tag_names`, `tag_ids`, `stats` — POST /v4/subscribers/filter
    Subscriber = Data.define(
      :id, :first_name, :email_address, :state,
      :created_at, :canceled_at, :location, :fields,
      :added_at, :tagged_at, :referrer, :referrer_utm_parameters,
      :attribution, :tags, :tag_names, :tag_ids, :stats
    ) do
      def self.from(hash)
        new(
          id: hash["id"], first_name: hash["first_name"], email_address: hash["email_address"],
          state: hash["state"], created_at: hash["created_at"], canceled_at: hash["canceled_at"],
          location: hash["location"], fields: hash["fields"],
          added_at: hash["added_at"], tagged_at: hash["tagged_at"], referrer: hash["referrer"],
          referrer_utm_parameters: hash["referrer_utm_parameters"], attribution: hash["attribution"],
          tags: hash["tags"], tag_names: hash["tag_names"], tag_ids: hash["tag_ids"], stats: hash["stats"]
        )
      end
    end
  end
end
