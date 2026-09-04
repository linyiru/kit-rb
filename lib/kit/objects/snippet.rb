# frozen_string_literal: true

module Kit
  module Objects
    # A snippet (reusable content) as returned by /v4/snippets. `snippet_type` is
    # "inline" or "document"; `content` holds an inline snippet's body and
    # `document` a document snippet's; `key` is the reference used in emails.
    Snippet = Data.define(
      :id, :name, :snippet_type, :archived, :key,
      :created_at, :updated_at, :content, :document
    ) do
      def self.from(hash)
        new(
          id: hash["id"], name: hash["name"], snippet_type: hash["snippet_type"],
          archived: hash["archived"], key: hash["key"], created_at: hash["created_at"],
          updated_at: hash["updated_at"], content: hash["content"], document: hash["document"]
        )
      end
    end
  end
end
