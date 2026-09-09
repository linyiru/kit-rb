# kit-rb

[![Gem Version](https://img.shields.io/gem/v/kit-rb?logo=rubygems&logoColor=white)](https://rubygems.org/gems/kit-rb)
[![Gem Downloads](https://img.shields.io/gem/dt/kit-rb?logo=rubygems&logoColor=white)](https://rubygems.org/gems/kit-rb)
[![CI](https://github.com/linyiru/kit-rb/actions/workflows/main.yml/badge.svg)](https://github.com/linyiru/kit-rb/actions/workflows/main.yml)
[![OpenAPI drift](https://github.com/linyiru/kit-rb/actions/workflows/contract-drift.yml/badge.svg)](https://github.com/linyiru/kit-rb/actions/workflows/contract-drift.yml)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.2-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![RBS + Steep](https://img.shields.io/badge/types-RBS%20%2B%20Steep-blue)](sig/kit-rb.rbs)
[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE.txt)

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

Which auth mode an account can use depends on its plan:

- **API keys work on every plan, including free.** Verified 2026-09-09 with a
  key from a `plan_type: "free"` account: account, subscriber and tag reads and
  writes all succeed. Kit positions keys as the owner's own automation and
  does not support public integrations built on them.
- **OAuth apps (App Store) need a paid plan.** On a free account the consent
  page redirects to Kit's billing settings instead of coming back to your
  `redirect_uri`, with no `error` parameter; the flow just never completes.
- The bulk and purchase endpoints require OAuth on any plan (an API key gets
  `401 OAuth authentication required`).
- `info.account.name` is `""` (not nil) when no name is set, so fall back to
  `info.account.primary_email_address` when presenting the account.
  `info.account.id` is the account id used in the App Store.

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
`max_backoff`) because Kit did not apply it; 5xx and transport failures are
retried only for idempotent verbs, so a POST is never replayed after those.
Credentials are masked in `#inspect`.

### Background jobs

The built-in retry sleeps on the calling thread, which is right for a script
and wrong inside a job: the job framework already owns retrying. Turn the
client's retries off and map the typed errors onto the framework's:

```ruby
class SyncSubscriberJob < ApplicationJob
  # grant_id identifies the stored OAuth pair for one Kit account (your model).
  def perform(grant_id, email_address, tag_id)
    grant = KitGrant.find(grant_id)
    renewed = false                 # outside the begin: `retry` must not reset it
    begin
      client = Kit::Client.new(access_token: grant.access_token, max_retries: 0) # never sleep in the worker
      subscriber = client.subscribers.create(email_address: email_address)     # upsert: safe to replay
      client.tags.tag_subscriber(tag_id, subscriber.id)                        # idempotent: safe to replay
    rescue Kit::RateLimitError => e
      wait = e.retry_after&.positive? ? e.retry_after : 30  # nil = no header, 0 = unparsable
      retry_job wait: wait.seconds
    rescue Kit::TransportError, Kit::ServerError
      # Only because every call above is safe to replay. The client itself does
      # not retry a POST after these (it does after a 429, which Kit did not
      # apply); a timed-out purchases.create may have succeeded and would append
      # its items again, so a job doing that must checkpoint or skip instead.
      raise                                                 # let retry_on / Sidekiq back off
    rescue Kit::AuthenticationError
      # With an API key a 401 means it was revoked: record it, tell the account
      # owner, and stop. With OAuth the access token may merely have expired:
      if renewed
        grant.mark_revoked!                                 # 401 on the renewed token: the grant is gone
        raise                                               # fail loudly; pair with discard_on
      end
      renewed = true
      grant.refresh!                                        # oauth.refresh(grant.refresh_token) + persist the new pair
      retry
    end
  end
end
```

- `max_retries: 0` disables *all* client-side retries, including the 429
  `Retry-After` sleep, so the job must read `RateLimitError#retry_after`
  itself: `nil` when Kit sent no header, `0` when it was not a number of
  seconds (an HTTP-date). Only a positive value is usable, so test for that
  rather than for `nil`.
- After a 5xx or transport failure the client does not replay a POST (it does
  after a 429, which Kit did not apply), so a job that retries a whole batch
  will re-run its earlier successful creates. Decide per operation whether
  that is safe. It is for the common ones:
  `POST /v4/subscribers` is an upsert (an existing email address gets its
  first name updated, nothing is duplicated), and `POST /v4/tags` is
  idempotent on name, matched case-insensitively (an existing tag answers 200
  with its record; a new one 201). It is not for `purchases.create`, whose
  product items are append-only. There is no single-tag delete in v4 —
  removing a tag needs `bulk.delete_tags` (OAuth).

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

`Kit::OAuth::Client.new` takes the same `open_timeout:` / `read_timeout:` /
`write_timeout:` options (and defaults) as `Kit::Client`, so a stalled token
endpoint cannot block a refresh indefinitely. Its transport failures raise the
same `Kit::TimeoutError` / `Kit::ConnectionError` (both `< Kit::TransportError`)
as the API client; `Kit::OAuthError` is the only error the token endpoint itself
produces. A transport error means no response was received, not that the request
was not processed: a timed-out `refresh` may already have consumed the single-use
refresh token, so treat retrying it as your own decision.

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
