# frozen_string_literal: true

module Kit
  module Objects
    # The user half of GET /v4/account.
    User = Data.define(:email, :id) do
      def self.from(hash)
        new(email: hash["email"], id: hash["id"])
      end
    end

    # The account's timezone, nested under account.timezone.
    Timezone = Data.define(:name, :friendly_name, :utc_offset) do
      def self.from(hash)
        new(name: hash["name"], friendly_name: hash["friendly_name"], utc_offset: hash["utc_offset"])
      end
    end

    # Billing plan details, nested under account.plan.
    Plan = Data.define(
      :plan_type, :interval, :subscriber_limit, :on_trial, :trial_lapse_date, :renews_at, :cancels_at
    ) do
      def self.from(hash)
        new(
          plan_type: hash["plan_type"], interval: hash["interval"], subscriber_limit: hash["subscriber_limit"],
          on_trial: hash["on_trial"], trial_lapse_date: hash["trial_lapse_date"],
          renews_at: hash["renews_at"], cancels_at: hash["cancels_at"]
        )
      end
    end

    # One verified sender address, listed under account.sending_addresses.
    SendingAddress = Data.define(
      :email_address, :from_name, :status, :is_default, :is_verified, :is_dmarc_configured
    ) do
      def self.from(hash)
        new(
          email_address: hash["email_address"], from_name: hash["from_name"], status: hash["status"],
          is_default: hash["is_default"], is_verified: hash["is_verified"],
          is_dmarc_configured: hash["is_dmarc_configured"]
        )
      end
    end

    # The account half of GET /v4/account. Extra fields Kit adds later are
    # ignored rather than crashing the client (forward-compatible). `timezone`
    # and `plan` are typed sub-objects (nil when absent); `sending_addresses` is
    # an Array of SendingAddress.
    Account = Data.define(
      :id, :name, :plan_type, :primary_email_address, :created_at,
      :timezone, :plan, :sending_addresses
    ) do
      def self.from(hash)
        new(
          id: hash["id"],
          name: hash["name"],
          plan_type: hash["plan_type"],
          primary_email_address: hash["primary_email_address"],
          created_at: hash["created_at"],
          timezone: hash["timezone"] && Timezone.from(hash["timezone"]),
          plan: hash["plan"] && Plan.from(hash["plan"]),
          sending_addresses: Array(hash["sending_addresses"]).map { |address| SendingAddress.from(address) }
        )
      end
    end

    # The whole GET /v4/account response: { user:, account: }.
    AccountInfo = Data.define(:user, :account) do
      def self.from(hash)
        new(
          user: User.from(hash.fetch("user", {})),
          account: Account.from(hash.fetch("account", {}))
        )
      end
    end
  end
end
