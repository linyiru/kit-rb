# frozen_string_literal: true

module Kit
  module Objects
    # A post (a broadcast published to the web) as returned by /v4/posts.
    # `publication_id` ties it back to the broadcast it was published from.
    Post = Data.define(
      :id, :publication_id, :created_at, :title, :slug, :description,
      :meta_description, :status, :published_at, :sent_at,
      :thumbnail_alt, :thumbnail_url, :is_paid, :public_url
    ) do
      def self.from(hash)
        new(
          id: hash["id"], publication_id: hash["publication_id"], created_at: hash["created_at"],
          title: hash["title"], slug: hash["slug"], description: hash["description"],
          meta_description: hash["meta_description"], status: hash["status"],
          published_at: hash["published_at"], sent_at: hash["sent_at"],
          thumbnail_alt: hash["thumbnail_alt"], thumbnail_url: hash["thumbnail_url"],
          is_paid: hash["is_paid"], public_url: hash["public_url"]
        )
      end
    end
  end
end
