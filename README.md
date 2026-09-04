# kit-rb

A modern, fully-typed Ruby client for the **Kit** (formerly ConvertKit) **API v4**.

The gem is named `kit-rb`; the public namespace is the clean `Kit`.

> Status: early. P0 (foundations + the `GET /v4/account` vertical slice) is in
> place; resources are landing per [`docs/DESIGN.md`](docs/DESIGN.md).

## Install

```ruby
gem "kit-rb"
```

Requires Ruby >= 3.2.

## Usage

```ruby
require "kit-rb"

# API key — simplest, for your own account (120 req / 60s):
client = Kit::Client.new(api_key: ENV.fetch("KIT_API_KEY"))

# or OAuth 2.0 (600 req / 60s; required for bulk & purchase endpoints):
client = Kit::Client.new(access_token: oauth_access_token)

info = client.account.get       # => Kit::Objects::AccountInfo
info.account.plan_type          # => "creator_pro"
info.user.email                 # => "you@example.com"
```

Responses are immutable `Data` value objects. Errors are typed:

```ruby
begin
  client.account.get
rescue Kit::AuthenticationError => e   # 401
  warn e.status                        # => 401
rescue Kit::RateLimitError => e        # 429
  sleep e.retry_after
rescue Kit::APIError => e              # any other non-2xx
  warn e.errors                        # => ["..."] from Kit's body
end
```

## Development

```sh
bin/setup
bundle exec rake        # spec + rubocop + steep
```

## License

MIT.
