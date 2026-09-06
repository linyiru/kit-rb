# kit-rb — design

A modern, fully-typed Ruby client for the **Kit** (formerly ConvertKit) **API v4**.
The existing Ruby gems all stop at API v3/v2; kit-rb targets v4 to a high bar.

> **Status: shipped.** All phases below are complete. v0.2.0 is on RubyGems;
> the post-0.2.0 hardening pass (`docs/TASKS.md`) completed the surface to all
> 83 documented operations, each pinned to the vendored OpenAPI document by
> contract tests.

## Locked decisions

| area | choice | why |
|---|---|---|
| HTTP | **http.rb** (`~> 5.2`) | one modern dependency; cleaner than Net::HTTP boilerplate, lighter than Faraday |
| Auth | **API key + OAuth 2.0 from day one** | Kit's bulk & purchase-creation endpoints require OAuth |
| Types | **RBS + steep**, response = **`Data` value objects** | Ruby-native, immutable, zero runtime type dep |
| Ruby floor | **3.2** | `Data.define` |
| Build process | P1 by hand; **P2 resources via local models + `forge`** | dogfood the reliable-edit workflow; Ruby verified across the fleet benchmarks |

## Architecture

```
Kit::Client            # entry: picks an auth strategy, holds one Connection
 ├─ Kit::Configuration # immutable; validates exactly-one-credential
 ├─ Kit::Auth::ApiKey  # X-Kit-Api-Key header
 ├─ Kit::Auth::OAuth   # Bearer; authorize/exchange/refresh/PKCE/revoke/client_credentials
 ├─ Kit::Connection    # http.rb transport, JSON, auth injection, error mapping
 ├─ Kit::Error (tree)  # typed exceptions mapped from HTTP status
 ├─ Kit::Objects::*    # Data value objects, `.from(hash)` constructors
 └─ Kit::Resources::*  # one class per resource group; client.account.get
```

Facts pinned from the OpenAPI spec (`developers.kit.com/api-reference/v4.json`,
OpenAPI 3.0.3, "Kit API 4.0", host `https://api.kit.com`, 52 paths / 83 operations,
vendored to `spec/support/kit-v4.openapi.json`): API-key
header `X-Kit-Api-Key`; OAuth authorize/token at `/v4/oauth/*`, scopes read/write;
rate limits 120/60s (key) and 600/60s (OAuth); cursor pagination (`after`/`before`
+ `per_page`, response carries a `pagination` object).

## Phases — all complete ✅

- **P0 — foundations. ✅** Gem skeleton on the clean `Kit` namespace, gates
  (rspec + rubocop + steep) green in CI (Ruby 3.2–3.4), and a walking-skeleton
  vertical slice: `GET /v4/account` end to end (auth → request → typed error →
  `Data` object) with full spec coverage.
- **P1 — core, by hand. ✅** Cursor auto-pagination (lazy Enumerator, POST-based
  lists supported), 429/5xx retry with backoff, and the full OAuth suite:
  authorization-code grant, single-use refresh, PKCE (S256), RFC 7009 revocation,
  and the client_credentials grant.
- **P2 — resources, spec-driven + local models. ✅** Every resource group shipped
  with objects + specs — subscribers, tags, custom fields, forms, sequences (+
  emails), broadcasts (+ stats/clicks), purchases, webhooks, webhook endpoints,
  email templates, segments, posts, snippets, account extras, and bulk. Early
  batches were dogfooded through `forge` against a local model on mbp; that
  surfaced the `Base#one`/`#collection` abstractions, after which the surface was
  completed by hand. 81 operations shipped in 0.2.0; the two PATCH operations
  landed in the hardening pass. **All 83 operations covered**, pinned by the
  contract specs.
- **P3 — quality. ✅** An OpenAPI list-envelope contract test (each list resource
  pinned to the vendored spec), plus VCR integration cassettes (secrets scrubbed)
  replayed in CI, `rake smoke` (live read-only), and an opt-in e2e lifecycle.
  99%+ line coverage; full RBS checked by Steep.
- **P4 — DX & release. ✅** README with usage/OAuth/testing docs, `rubygems_mfa_
  required`, and a GitHub Actions **OIDC Trusted Publishing** workflow (tag `v*`
  → gated release, no stored key). v0.1.0 and v0.2.0 published this way.
  Deferred (optional): a hosted YARD site and cryptographic gem signing.
- **P5 — hardening (2026-09-06). ✅** A full audit against the OpenAPI document
  and the live docs, tracked row by row in `docs/TASKS.md`: two real-API bugs
  (204 unsubscribe, dropped webhook secret), safety (credential masking, path
  id validation, no POST replay, Retry-After cap), the missing PATCH
  operations and response fields, incoming-webhook verification, typed bulk
  results and transport errors, explicit keyword bodies with tightened RBS,
  and contract tests over object envelopes, request bodies and 204s.
