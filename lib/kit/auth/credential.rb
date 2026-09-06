# frozen_string_literal: true

module Kit
  module Auth
    # Renders a secret for #inspect output: the last four characters behind a
    # fixed-width mask, so two clients can be told apart in a log without the
    # log ever containing a usable credential. Short secrets are fully masked.
    module Credential
      MASK = "****"
      VISIBLE = 4

      def self.mask(secret)
        return "nil" if secret.nil?

        value = secret.to_s
        return MASK if value.length <= VISIBLE * 2

        "#{MASK}#{value[-VISIBLE..]}"
      end
    end
  end
end
