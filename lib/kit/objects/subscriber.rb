# frozen_string_literal: true

module Kit
  module Objects
    # A subscriber as returned by /v4/subscribers. `fields` holds custom-field
    # values; `location` is present on some responses; both are plain Hashes.
    Subscriber = Data.define(
      :id, :first_name, :email_address, :state,
      :created_at, :canceled_at, :location, :fields
    ) do
      def self.from(hash)
        new(
          id: hash["id"],
          first_name: hash["first_name"],
          email_address: hash["email_address"],
          state: hash["state"],
          created_at: hash["created_at"],
          canceled_at: hash["canceled_at"],
          location: hash["location"],
          fields: hash["fields"]
        )
      end
    end
  end
end
