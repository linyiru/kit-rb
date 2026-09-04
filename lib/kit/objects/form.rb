# frozen_string_literal: true

module Kit
  module Objects
    # A form as returned by /v4/forms. `type` is e.g. "embed"/"hosted"; `uid` is
    # the public identifier used in embed URLs. `subscriber_count` is present
    # only when the request asks to include it.
    Form = Data.define(
      :id, :name, :created_at, :type, :format,
      :embed_js, :embed_url, :archived, :uid, :subscriber_count
    ) do
      def self.from(hash)
        new(
          id: hash["id"], name: hash["name"], created_at: hash["created_at"],
          type: hash["type"], format: hash["format"], embed_js: hash["embed_js"],
          embed_url: hash["embed_url"], archived: hash["archived"], uid: hash["uid"],
          subscriber_count: hash["subscriber_count"]
        )
      end
    end
  end
end
