# frozen_string_literal: true

module Kit
  # Immutable per-client configuration. Exactly one credential (api_key or
  # access_token) must be supplied; the matching auth strategy is selected here.
  class Configuration
    attr_reader :auth, :base_url, :open_timeout, :read_timeout

    def initialize(api_key: nil, access_token: nil, base_url: DEFAULT_BASE_URL,
                   open_timeout: 10, read_timeout: 30)
      @auth = build_auth(api_key, access_token)
      @base_url = base_url
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    private

    def build_auth(api_key, access_token)
      raise ConfigurationError, "supply either api_key or access_token, not both" if api_key && access_token

      return Auth::ApiKey.new(api_key) if api_key
      return Auth::OAuth.new(access_token) if access_token

      raise ConfigurationError, "an api_key or access_token is required"
    end
  end
end
