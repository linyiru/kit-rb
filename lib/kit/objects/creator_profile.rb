# frozen_string_literal: true

module Kit
  module Objects
    # A creator profile as returned by /v4/account/creator_profile.
    CreatorProfile = Data.define(:name, :byline, :bio, :image_url, :profile_url) do
      def self.from(hash)
        new(name: hash["name"], byline: hash["byline"], bio: hash["bio"],
            image_url: hash["image_url"], profile_url: hash["profile_url"])
      end
    end
  end
end
