# frozen_string_literal: true

module Kit
  module Objects
    # A segment (a saved subscriber filter) as returned by /v4/segments.
    Segment = Data.define(:id, :name, :created_at) do
      def self.from(hash)
        new(id: hash["id"], name: hash["name"], created_at: hash["created_at"])
      end
    end
  end
end
