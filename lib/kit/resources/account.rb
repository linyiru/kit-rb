# frozen_string_literal: true

module Kit
  module Resources
    # The /v4/account endpoints: the current account, its colour palette,
    # creator profile, and account-wide email and growth stats.
    class Account < Base
      # GET /v4/account — current account and user info.
      #
      # @return [Kit::Objects::AccountInfo]
      def get
        Objects::AccountInfo.from(http_get("/v4/account"))
      end

      # GET /v4/account/colors — the account's brand color palette (hex strings).
      def colors
        extract(http_get("/v4/account/colors"), "colors")
      end

      # PUT /v4/account/colors — replace the palette; returns the saved colors.
      def update_colors(colors)
        extract(http_put("/v4/account/colors", body: { colors: colors }), "colors")
      end

      # GET /v4/account/creator_profile
      def creator_profile
        one(:get, "/v4/account/creator_profile", "profile", Objects::CreatorProfile)
      end

      # GET /v4/account/email_stats — account-wide email engagement stats.
      def email_stats
        one(:get, "/v4/account/email_stats", "stats", Objects::EmailStats)
      end

      # GET /v4/account/growth_stats — subscriber-growth stats; accepts
      # starting/ending to bound the window.
      def growth_stats(**params)
        one(:get, "/v4/account/growth_stats", "stats", Objects::GrowthStats, params: params)
      end
    end
  end
end
