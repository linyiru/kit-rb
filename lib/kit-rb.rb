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
require "kit/auth/credential"
require "kit/auth/api_key"
require "kit/auth/oauth"
require "kit/connection"
require "kit/pagination"
require "kit/oauth/pkce"
require "kit/oauth/token"
require "kit/oauth/client"
require "kit/objects/account"
require "kit/objects/creator_profile"
require "kit/objects/subscriber"
require "kit/objects/tag"
require "kit/objects/custom_field"
require "kit/objects/form"
require "kit/objects/sequence"
require "kit/objects/sequence_email"
require "kit/objects/broadcast"
require "kit/objects/broadcast_stats"
require "kit/objects/broadcast_click"
require "kit/objects/subscriber_stats"
require "kit/objects/email_stats"
require "kit/objects/growth_stats"
require "kit/objects/webhook"
require "kit/objects/webhook_endpoint"
require "kit/objects/email_template"
require "kit/objects/segment"
require "kit/objects/post"
require "kit/objects/snippet"
require "kit/objects/purchase"
require "kit/objects/bulk_result"
require "kit/resources/base"
require "kit/resources/account"
require "kit/resources/subscribers"
require "kit/resources/tags"
require "kit/resources/custom_fields"
require "kit/resources/forms"
require "kit/resources/sequences"
require "kit/resources/broadcasts"
require "kit/resources/webhooks"
require "kit/resources/webhook_endpoints"
require "kit/resources/email_templates"
require "kit/resources/segments"
require "kit/resources/posts"
require "kit/resources/snippets"
require "kit/resources/purchases"
require "kit/resources/bulk"
require "kit/client"
