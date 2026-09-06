# kit-rb

A modern, fully-typed Ruby client for the **Kit** (formerly ConvertKit) **API v4**.

The gem is named `kit-rb`; the public namespace is the clean `Kit`.

> Status: the full v4 surface is implemented — every one of the 83 documented
> operations across all resources, pinned to the vendored OpenAPI document by
> contract tests. See [`docs/DESIGN.md`](docs/DESIGN.md).

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

Responses are immutable `Data` value objects. Errors are typed, and every one
is a `Kit::Error`:

```ruby
begin
  client.subscribers.get(42)
rescue Kit::NotFoundError => e         # 404 — also 401/403/409/413/422 classes
  warn e.message                       # => "GET /v4/subscribers/42 failed with status 404: ..."
rescue Kit::RateLimitError => e        # 429 — honours Retry-After
  sleep e.retry_after
rescue Kit::APIError => e              # any other non-2xx: e.status, e.errors, e.method, e.path
rescue Kit::TimeoutError, Kit::ConnectionError => e  # never got a response (< Kit::TransportError)
rescue Kit::UnexpectedResponseError => e # 2xx whose body is not the documented shape
end
```

A 429 is retried for every request (with `Retry-After`, capped at
`max_backoff`); 5xx and transport failures are retried only for idempotent
verbs, so a POST is never replayed. Credentials are masked in `#inspect`.

## Resources

`client.` exposes: `account`, `subscribers`, `tags`, `custom_fields`, `forms`,
`sequences` (incl. its emails and subscribers), `broadcasts` (incl. stats and
click reports), `email_templates`, `segments`, `posts`, `snippets`, `purchases`,
`webhooks`, `webhook_endpoints`, and `bulk`.

### Pagination

List endpoints return a `Kit::Collection` — `Enumerable` over the current page
(`size`, `empty?`, `[]`), with lazy cursor following:

```ruby
client.subscribers.list.each { |s| ... }              # current page
client.subscribers.list.auto_paging_each { |s| ... }  # every page, lazily
page = client.subscribers.list(status: "active", per_page: 100, include_total_count: true)
page.total_count                                      # => 1234 (first page only, as Kit asks)
```

### Bulk

The `bulk` endpoints (OAuth only) return a `Kit::Objects::BulkResult`:

```ruby
result = client.bulk.create_tags([{ name: "vip" }, { name: "" }])
result.async?           # true when Kit queued the batch (202) and will POST to callback_url
result.items            # the affected records (raw Hashes; shape varies per endpoint)
result.failures         # => [#<BulkFailure item={"name"=>""} errors=["Name can't be blank"]>]
```

### Receiving webhooks

Endpoints created with `client.webhook_endpoints.create` return their signing
`secret` once. Verify and parse each delivery with it:

```ruby
delivery = Kit::Webhooks::Delivery.from_request(
  request.raw_post, request.headers["X-Kit-Signature"], secret: ENV.fetch("KIT_WEBHOOK_SECRET")
)                                                     # raises Kit::Webhooks::SignatureError
delivery.events.each { |e| handle(e.type, e.data) unless seen?(e.id) }

Kit::Webhooks::Events::SUBSCRIBER_TAG_ADDED           # => "subscriber.tag_added" (all 28 listed)
```

Signatures are HMAC-SHA256 over `"#{t}.#{raw_body}"` with a 300 s replay window;
both secrets are accepted during a rotation.

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
- **Contract** — every list and single-object operation, every create/update
  request body, and every 204 response is pinned to the vendored OpenAPI
  document, so reading the wrong envelope, sending an undocumented field, or
  parsing a no-content response fails automatically. A weekly workflow diffs
  the vendored document against Kit's and fails on drift.
- **Integration** — real recorded responses (VCR cassettes, secrets scrubbed)
  replayed in CI, proving the live shapes still parse into our value objects.
- **Smoke** — `rake smoke` hits every read endpoint live (needs `KIT_API_KEY`).
- **E2E** — an opt-in (`KIT_E2E=1`) create→update→list→delete lifecycle that
  cleans up after itself.
- **Types** — full RBS signatures (explicit keywords on every create/update),
  checked with Steep. Line and branch coverage are enforced at 90%.

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
