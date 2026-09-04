# frozen_string_literal: true

module Kit
  module Objects
    # A custom field as returned by /v4/custom_fields. `label` is what a creator
    # sets; `key` is the derived attribute used on subscribers (e.g. a `label`
    # of "Last name" yields a `key` of "last_name").
    CustomField = Data.define(:id, :name, :key, :label) do
      def self.from(hash)
        new(id: hash["id"], name: hash["name"], key: hash["key"], label: hash["label"])
      end
    end
  end
end
