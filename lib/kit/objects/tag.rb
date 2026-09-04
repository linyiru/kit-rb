# frozen_string_literal: true

module Kit
  module Objects
    # A tag as returned by /v4/tags. Fields are all non-nil.
    Tag = Data.define(:id, :name, :created_at, :subscriber_count) do
      def self.from(hash)
        new(
          id: hash["id"],
          name: hash["name"],
          created_at: hash["created_at"],
          subscriber_count: hash["subscriber_count"]
        )
      end
    end
  end
end
