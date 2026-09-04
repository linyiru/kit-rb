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
        Objects::AccountInfo.from(super("/v4/account"))
      end
    end
  end
end
