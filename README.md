# qdrant-client

[![CI](https://github.com/jbox-web/qdrant-client.cr/actions/workflows/ci.yml/badge.svg)](https://github.com/jbox-web/qdrant-client.cr/actions/workflows/ci.yml)
[![Docs](https://github.com/jbox-web/qdrant-client.cr/actions/workflows/docs.yml/badge.svg)](https://jbox-web.github.io/qdrant-client.cr)
[![Release](https://img.shields.io/github/v/release/jbox-web/qdrant-client.cr?include_prereleases&sort=semver)](https://github.com/jbox-web/qdrant-client.cr/releases)
[![Crystal](https://img.shields.io/badge/crystal-%3E%3D%201.18-black?logo=crystal)](https://crystal-lang.org)
[![License](https://img.shields.io/github/license/jbox-web/qdrant-client.cr)](LICENSE)

Idiomatic, RAG-oriented [Qdrant](https://qdrant.tech) client for Crystal — a thin,
**stable** wrapper over [`qdrant-api`](https://github.com/jbox-web/qdrant-api.cr)
(the generated, fully-typed transport layer). It exposes exactly the vector working
set a retrieval engine needs — create a collection, upsert vectors, KNN search,
delete by id, count — and nothing else.

> Need the full Qdrant surface (filters, scroll, snapshots, cluster, aliases,
> sparse/multi-vectors…)? Reach for [`qdrant-api`](https://github.com/jbox-web/qdrant-api.cr)
> directly. This shard is the opinionated sugar on top of it.

## Features

- **Stable, hand-written API** — `Qdrant::Collection` + `Qdrant::Hit`. No generated
  type ever leaks into the public surface (anti-corruption layer): when `qdrant-api`
  is regenerated against a new Qdrant release, the compiler localizes any drift to a
  handful of internal call sites, not your code.
- **The RAG working set, ~5 ops** — `ensure`, `upsert` (single + batch), `search`,
  `delete(ids)`, `count`. Deliberately no filter DSL: deletes go by id, KNN is
  unfiltered (fuse on your side).
- **Connection as the happy path** — an existing, often remote Qdrant (Qdrant Cloud):
  HTTPS + `api-key` header, one dedicated collection per corpus.
- **Tested against a real Qdrant** — the spec suite runs against a Qdrant container,
  doubling as a contract/canary check in CI.

## Installation

Add the dependency to your `shard.yml`:

```yaml
dependencies:
  qdrant-client:
    github: jbox-web/qdrant-client.cr
```

Then run `shards install`.

## Usage

```crystal
require "qdrant-client"

# An existing Qdrant, often remote / Cloud → HTTPS + api-key header.
docs = Qdrant::Collection.new("docs",
  url: "https://my-qdrant:6333",
  api_key: ENV["QDRANT_API_KEY"]?)

docs.ensure(dim: 768, distance: :cosine)          # idempotent
docs.upsert(42_i64, embedding)                     # single
docs.upsert([                                      # batch
  {43_i64, embedding_a},
  {44_i64, embedding_b},
])

hits = docs.search(query_embedding, top_k: 20)     # => Array(Qdrant::Hit){id, score}
hits.first.id      # Int64
hits.first.score   # Float32

docs.delete([42_i64, 43_i64])                      # purge by id
docs.count                                         # Int64
```

`Qdrant::Hit` is the only stable result type — `{id : Int64, score : Float32,
payload : Hash(String, JSON::Any)}`. Search returns `{id, score}`; hydrate the
content from your own store of record by id.

## Compatibility

The chain `qdrant-client → qdrant-api → pinned OpenAPI spec → Qdrant server` isn't
obvious from a version number alone, so it's spelled out here:

| `qdrant-client` | `qdrant-api` | Qdrant server (CI canary) |
| --- | --- | --- |
| 0.1.x | ~> 0.1 | v1.12.x |

> Qdrant point ids are modeled as `Int32` by the OpenAPI layer (`ExtendedPointId`).
> `Qdrant::Hit#id` is exposed as `Int64` but round-trips through `Int32` — safe as
> long as ids stay below 2³¹.

## Development

```bash
mise dev:deps        # shards install
mise dev:qdrant-up   # local Qdrant container (integration specs)
mise dev:check       # build + ameba + specs
mise dev:qdrant-down
```

## License

[MIT](LICENSE) — Nicolas Rodriguez.
