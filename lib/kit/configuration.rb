# frozen_string_literal: true

module Kit
  # Immutable per-client configuration. Exactly one credential (api_key or
  # access_token) must be supplied; the matching auth strategy is selected here.
  class Configuration
    attr_reader :auth, :base_url, :open_timeout, :read_timeout, :write_timeout,
                :max_retries, :retry_backoff, :max_backoff

    def initialize(api_key: nil, access_token: nil, base_url: DEFAULT_BASE_URL,
                   open_timeout: 10, read_timeout: 30, write_timeout: 30,
                   max_retries: 2, retry_backoff: 0.5, max_backoff: 30)
      @auth = build_auth(api_key, access_token)
      @base_url = base_url
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      @write_timeout = write_timeout   # http 5 would otherwise default to 0.25 s
      @max_retries = max_retries       # 0 disables automatic retries
      @retry_backoff = retry_backoff   # base seconds for exponential backoff
      @max_backoff = max_backoff       # cap on any single sleep
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
