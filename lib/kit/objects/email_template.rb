# frozen_string_literal: true

module Kit
  module Objects
    # An email template as returned by /v4/email_templates. `is_default` marks the
    # account's default; `category` groups templates in the UI.
    EmailTemplate = Data.define(:id, :name, :is_default, :category) do
      def self.from(hash)
        new(id: hash["id"], name: hash["name"],
            is_default: hash["is_default"], category: hash["category"])
      end
    end
  end
end
