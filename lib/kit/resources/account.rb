# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/account endpoints. P0 covers the current-account read; colors,
    # creator_profile, email_stats, and growth_stats follow in P1/P2.
    class Account < Base
      # GET /v4/account — current account and user info.
      #
      # @return [Kit::Objects::AccountInfo]
      def get
        Objects::AccountInfo.from(http_get("/v4/account"))
      end

      # GET /v4/account/colors — the account's brand color palette (hex strings).
      def colors
        http_get("/v4/account/colors").fetch("colors")
      end

      # PUT /v4/account/colors — replace the palette; returns the saved colors.
      def update_colors(colors)
        http_put("/v4/account/colors", body: { colors: colors }).fetch("colors")
      end

      # GET /v4/account/creator_profile
      def creator_profile
        one(:get, "/v4/account/creator_profile", "profile", Objects::CreatorProfile)
      end

      # GET /v4/account/email_stats — returns the raw stats hash.
      def email_stats
        http_get("/v4/account/email_stats").fetch("stats")
      end

      # GET /v4/account/growth_stats — raw stats hash; accepts starting/ending.
      def growth_stats(**params)
        http_get("/v4/account/growth_stats", params: params).fetch("stats")
      end
    end
  end
end
