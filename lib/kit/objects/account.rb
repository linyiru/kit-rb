# frozen_string_literal: true

module Kit
  module Objects
    # The user half of GET /v4/account.
    User = Data.define(:email, :id) do
      def self.from(hash)
        new(email: hash["email"], id: hash["id"])
      end
    end

    # The account half of GET /v4/account. Extra fields Kit adds later are
    # ignored rather than crashing the client (forward-compatible).
    Account = Data.define(:id, :name, :plan_type, :primary_email_address, :created_at) do
      def self.from(hash)
        new(
          id: hash["id"],
          name: hash["name"],
          plan_type: hash["plan_type"],
          primary_email_address: hash["primary_email_address"],
          created_at: hash["created_at"]
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
