# Tasks

Progress tracker for the post-0.2.0 hardening pass. Each row lands as one atomic
commit with its own specs; the row is ticked in the same commit. Findings come
from the 2026-09-04 audit of the gem against the vendored OpenAPI document
(`spec/support/kit-v4.openapi.json`, 52 paths / 83 operations) and the live docs.

Legend: `[ ]` todo · `[x]` done (commit noted).

## P0 — breaks against the real API

- [x] `subscribers.unsubscribe` calls `one(...)` on a 204 no-body response → `NoMethodError`. (`fix: subscribers.unsubscribe handles the 204 no-content response`)
- [x] `WebhookEndpoint` drops `secret`, the only time Kit returns the signing secret (`create`, `rotate_secret`). (`fix: WebhookEndpoint carries the one-time signing secret`)
- [x] `Retry-After` on 429 is honoured without the `max_backoff` cap (a 30 s header blocks the caller for 60 s). (`fix: cap Retry-After at max_backoff`)
- [x] Error-mapping specs really sleep: the 429 example alone costs 60 s per CI run. (`test: stop error-mapping specs from really sleeping`)
- [x] Unexpected response shapes surface as `KeyError` / `NoMethodError` instead of a `Kit::Error`. (`fix: raise Kit::UnexpectedResponseError on drifted 2xx bodies`)
- [x] Path ids are interpolated unescaped and unvalidated (`get("1/unsubscribe?x")`, `get(nil)`). (`fix: validate and percent-encode path ids`)
- [x] Non-idempotent POSTs are retried on 5xx (duplicate creates). (`fix: do not replay POSTs after a 5xx`)

## P1 — security / correctness

- [x] `Client`, `Configuration`, `Auth::*`, `OAuth::Token` `#inspect` print the credential in plaintext. (`fix: mask credentials in inspect output`)
- [x] `total_count` is discarded by `Pagination.from`; auto-paging resends `include_total_count` on every page; a `before:` param leaks into `after:` follow-ups. (`feat: surface total_count and fix follow-up page params`)
- [x] No error classes for 409 (rotate_secret conflict) and 413 (bulk quota). (`feat: typed errors for 409 and 413`)
- [x] 202 (async bulk) indistinguishable from 200; bulk methods return raw Hashes. (`feat: typed BulkResult with async (202) detection`)
- [x] Error messages omit the request method and path. (`feat: name the failed request in APIError messages`)

## P2 — API coverage

- [x] `PATCH /v4/subscribers/{id}/location` (`subscribers.update_location`). (`feat: subscribers.update_location and stats date window`)
- [x] `PATCH /v4/webhook_endpoints/{id}` (`webhook_endpoints.update`). (`feat: webhook_endpoints.update`)
- [x] `sequences.get` / `sequences.email` cannot send `include=stats`; `subscribers.stats` cannot send `email_sent_after/before`. (`feat: include=stats on sequences.get and sequences.email`, `feat: subscribers.update_location and stats date window`)
- [x] Missing response fields: `Account` (`timezone`, `plan`, `sending_addresses`), `Post#content`, `SequenceEmail#content`, `Subscriber` (`added_at`, `referrer`, `referrer_utm_parameters`, `tagged_at`, `attribution`, `tags`), `Tag#tagged_at`, `CustomField#created_at`. (`feat: complete the value objects against the spec's response schemas`)
- [x] Incoming webhooks: `X-Kit-Signature` HMAC-SHA256 verification and delivery-envelope parsing. (`feat: verify and parse incoming webhook deliveries`)
- [x] Webhook event-name constants. (`feat: webhook event-name constants`)

## P3 — engineering quality / DX

- [x] `Collection` lacks `size`, `empty?`, `[]`, and a readable `inspect`. (`feat: Collection#size, #empty?, #[] and a readable inspect`)
- [x] Transport errors (timeouts, connection refused) collapse into the generic `Kit::Error`. (`feat: typed transport errors, retried for idempotent requests`)
- [x] One `HTTP::Client` per request: no persistent connections. Client is now built once per Connection; true keep-alive (`HTTP.persistent`) is deliberately not used because it is not thread-safe while `Kit::Client` is documented as shareable. (`perf: build the http.rb client once per Connection`)
- [x] Stale P0/P1 comments in `auth/oauth.rb`, `resources/account.rb`, `sig/kit-rb.rbs`; unused `Auth::OAuth::*_URL` constants; template comments in the gemspec. (`chore: drop stale phase comments, dead constants, and gemspec boilerplate`)
- [ ] README / DESIGN.md claim 81 operations; the spec has 83.
- [x] CI matrix lacks Ruby 3.5; no Dependabot; no branch coverage. (`ci: test on Ruby 3.5, add Dependabot, enforce branch coverage`)
- [x] RBS: 22 methods take `**untyped`; tighten the fixed-key bodies (broadcasts, sequences, sequence emails, snippets, purchases). List query params stay `**params`. (`refactor: explicit keyword bodies for create/update methods`)
- [x] OpenAPI contract test covers only list envelopes; extend to single-object envelopes and request bodies. (`test: contract-check object envelopes, request bodies, and 204s against the spec`)
- [ ] `rake contract:fetch` is manual; add a scheduled drift check.
