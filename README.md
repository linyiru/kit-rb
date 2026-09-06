# kit-rb

A modern, fully-typed Ruby client for the **Kit** (formerly ConvertKit) **API v4**.

The gem is named `kit-rb`; the public namespace is the clean `Kit`.

> Status: the full v4 surface is implemented — every one of the 81 documented
> operations across all resources, verified against the vendored OpenAPI
> document. See [`docs/DESIGN.md`](docs/DESIGN.md).

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
```

Responses are immutable `Data` value objects. Errors are typed:

```ruby
begin
  client.account.get
rescue Kit::AuthenticationError => e   # 401
  warn e.status                        # => 401
rescue Kit::RateLimitError => e        # 429 — honours Retry-After
  sleep e.retry_after
rescue Kit::APIError => e              # any other non-2xx
  warn e.errors                        # => ["..."] from Kit's body
end
```

Transient failures (429 and 5xx) are retried automatically with backoff.

## Resources

`client.` exposes: `account`, `subscribers`, `tags`, `custom_fields`, `forms`,
`sequences` (incl. its emails and subscribers), `broadcasts` (incl. stats and
click reports), `email_templates`, `segments`, `posts`, `snippets`, `purchases`,
`webhooks`, `webhook_endpoints`, and `bulk`.

### Pagination

List endpoints return a `Kit::Collection` — `Enumerable` over the current page,
with lazy cursor following:

```ruby
client.subscribers.list.each { |s| ... }              # current page
client.subscribers.list.auto_paging_each { |s| ... }  # every page, lazily
client.subscribers.list(status: "active", per_page: 100)
```

### OAuth 2.0

```ruby
oauth = Kit::OAuth::Client.new(client_id: ID, client_secret: SECRET,
                               redirect_uri: "https://app.example/callback")

redirect_to oauth.authorization_url(state: session_token)   # consent
token = oauth.exchange_code(params[:code])                  # => Kit::OAuth::Token
token = oauth.refresh(token.refresh_token)                  # single-use refresh
oauth.revoke(token.access_token)                            # RFC 7009

client = Kit::Client.new(access_token: token.access_token)
```

Public clients (SPA/mobile/CLI) use PKCE via `Kit::OAuth::PKCE.generate` and omit
the client secret. `oauth.client_credentials` mints an app-only token (note: Kit
rejects it on the resource endpoints — account access needs the consent flow).

## Testing

The suite is layered:

- **Unit** — every method against WebMock stubs.
- **Contract** — each list resource is pinned to the vendored OpenAPI document,
  so reading the wrong response envelope fails automatically.
- **Integration** — real recorded responses (VCR cassettes, secrets scrubbed)
  replayed in CI, proving the live shapes still parse into our value objects.
- **Smoke** — `rake smoke` hits every read endpoint live (needs `KIT_API_KEY`).
- **E2E** — an opt-in (`KIT_E2E=1`) create→update→list→delete lifecycle that
  cleans up after itself.
- **Types** — full RBS signatures, checked with Steep.

```sh
bin/setup
bundle exec rake        # spec + rubocop + steep
bundle exec rake smoke  # live read-only smoke (needs a key)
```

`bin/setup` points `core.hooksPath` at `.githooks/`, so a **pre-commit** hook
runs RuboCop on staged Ruby files and a **pre-push** hook runs the full
`bundle exec rake` gate. Both rely on exit codes, not parsed output — a red gate
cannot be committed or pushed.

## License

MIT.
