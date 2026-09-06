# frozen_string_literal: true

module Kit
  module Objects
    # A tag as returned by /v4/tags. `tagged_at` is set only when the tag is
    # read through a subscriber (/v4/subscribers/:id/tags): when it was applied.
    Tag = Data.define(:id, :name, :created_at, :subscriber_count, :tagged_at) do
      def self.from(hash)
        new(
          id: hash["id"],
          name: hash["name"],
          created_at: hash["created_at"],
          subscriber_count: hash["subscriber_count"],
          tagged_at: hash["tagged_at"]
        )
      end
    end
  end
end
