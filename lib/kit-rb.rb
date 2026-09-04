# frozen_string_literal: true

# kit-rb — a Ruby client for the Kit (formerly ConvertKit) API v4.
#
# The gem is named `kit-rb`; the public namespace is the clean `Kit`
# (like redis-rb → Redis). Require it and talk to the API through a client:
#
#   client = Kit::Client.new(api_key: ENV.fetch("KIT_API_KEY"))
#   client.account.get.plan_type # => "creator_pro"
module Kit
  # Base URL for the v4 REST API. Overridable per-client for tests/mocks.
  DEFAULT_BASE_URL = "https://api.kit.com"
end

require "kit/version"
require "kit/errors"
require "kit/configuration"
require "kit/auth/api_key"
require "kit/auth/oauth"
require "kit/connection"
require "kit/pagination"
require "kit/oauth/pkce"
require "kit/oauth/token"
require "kit/oauth/client"
require "kit/objects/account"
require "kit/objects/subscriber"
require "kit/objects/tag"
require "kit/objects/custom_field"
require "kit/objects/form"
require "kit/objects/sequence"
require "kit/resources/base"
require "kit/resources/account"
require "kit/resources/subscribers"
require "kit/resources/tags"
require "kit/resources/custom_fields"
require "kit/resources/forms"
require "kit/resources/sequences"
require "kit/client"
