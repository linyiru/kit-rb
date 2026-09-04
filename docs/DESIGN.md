# kit-rb — design

A modern, fully-typed Ruby client for the **Kit** (formerly ConvertKit) **API v4**.
The existing Ruby gems all stop at API v3/v2; kit-rb targets v4 to a high bar.

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
 ├─ Kit::Auth::OAuth   # Bearer; authorize/refresh/PKCE land in P1
 ├─ Kit::Connection    # http.rb transport, JSON, auth injection, error mapping
 ├─ Kit::Error (tree)  # typed exceptions mapped from HTTP status
 ├─ Kit::Objects::*    # Data value objects, `.from(hash)` constructors
 └─ Kit::Resources::*  # one class per resource group; client.account.get
```

Facts pinned from the OpenAPI spec (`developers.kit.com/api-reference/v4.json`,
OpenAPI 3.0.3, "Kit API 4.0", host `https://api.kit.com`, 52 paths): API-key
header `X-Kit-Api-Key`; OAuth authorize/token at `/v4/oauth/*`, scopes read/write;
rate limits 120/60s (key) and 600/60s (OAuth); cursor pagination (`after`/`before`
+ `per_page`, response carries a `pagination` object).

## Phases

- **P0 — foundations (this).** Gem skeleton on the clean `Kit` namespace, gates
  (rspec + rubocop + steep) green in CI (Ruby 3.2–3.4), and a walking-skeleton
  vertical slice: `GET /v4/account` end to end (auth → request → typed error →
  `Data` object) with full spec coverage.
- **P1 — core, by hand.** Flesh out the transport: cursor auto-pagination
  (lazy Enumerator), 429 rate-limit-aware retry with backoff, the full OAuth
  authorization-code grant + refresh + PKCE, and instrumentation hooks.
- **P2 — resources, spec-driven + local models.** One class + objects + specs per
  resource group (subscribers, tags, custom fields, forms, sequences, broadcasts,
  purchases, webhooks, email templates, segments, snippets), generated against
  the OpenAPI spec via `forge`, gated by `rspec`/`steep`.
- **P3 — quality.** Contract tests against the OpenAPI spec, edge cases
  (pagination tail, nulls, large payloads), coverage floor.
- **P4 — DX & release.** YARD docs, examples, signed gem, release automation.
