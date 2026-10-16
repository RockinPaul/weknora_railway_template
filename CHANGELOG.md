# Changelog

## 2026-10-16 — WeKnora v0.8.3, and ParadeDB v0.25.11 for Postgres

- `frontend`, `app` and `docreader` run `wechatopenai/weknora-ui`, `-app` and `-docreader` `:v0.8.3` (were v0.8.2). The nginx config upstream ships is unchanged, so `web/` only changes its version comments.
- Security fixes since v0.8.2 include scoping agent database queries to the shared knowledge bases a user may see, keeping LLM debug records inside their directory, and size caps on connector API responses (Yuque, Notion, IMA, Feishu).
- **The `Postgres` service should move to `paradedb/paradedb:v0.25.11-pg17`** (new deploys get it from the template). Upstream found that large imports on the v0.22 images can drive Postgres into a crash-and-recovery loop: the pgvector 0.8.1 those images ship has HNSW index corruption bugs fixed in 0.8.2–0.8.4, and pg_search had no crash recovery before 0.24. The image is a Railway service setting, not a file in this repo, so **an existing deployment keeps v0.22.2 until you change it** — see below.
- `docreader` now starts through upstream's own entrypoint, which only changes anything on ARM machines. New optional `app` variables for outbound and parser timeouts (`WEKNORA_OUTBOUND_DIAL_TIMEOUT`, `WEKNORA_MINERU_TIMEOUT` and others); unset means upstream's defaults.

### Upgrading an existing deployment

Back up Postgres and the `app` volume first. `app` migrates the schema from version 110 to 118 on its first start (forward-only).

**Recommended order: change the database image first, then apply this update.**

1. On the `Postgres` service, set the source image to `paradedb/paradedb:v0.25.11-pg17` and redeploy it. Keep the volume and variables. The current `app` keeps working on it.
2. Apply the template update. On its first start `app` upgrades the extensions in the `weknora` database to match the image (`pg_search` 0.25.11, `vector` 0.8.4).
3. Optional, for databases created later from `template1`: in the `Postgres` service shell run `psql -U postgres -d template1 -c "ALTER EXTENSION pg_search UPDATE; ALTER EXTENSION vector UPDATE;"`.

**If you applied this update before changing the image**, the migration that upgrades the extensions has already run and found nothing to do, and it does not run again. After switching the image, run in the `Postgres` service shell:

```
psql -U postgres -d weknora -c "ALTER EXTENSION pg_search UPDATE; ALTER EXTENSION vector UPDATE;"
```

(and the same with `-d template1`). Without it the database runs the new libraries against the old extension catalog, which upstream reports can crash the server when some pg_search functions are called.

Staying on v0.22.2 also works with v0.8.3, but keeps the crash risk on large imports. Once Postgres has run on v0.25.11 you cannot go back to the v0.22.2 image on the same volume, because the old image cannot replay the newer write-ahead log; going back means restoring the backup.

Verified locally with the template's wrappers and variables:

- **Image first:** a v0.8.2 database on ParadeDB v0.22.2 with 300 indexed rows moved to v0.25.11, with `app` still on v0.8.2. Then `app` v0.8.3 migrated it to 118 and upgraded both extensions. Keyword (BM25) and vector search returned identical results before and after, and new rows were indexed and found.
- **App first:** v0.8.3 on ParadeDB v0.22.2 migrated a v0.8.2 database, kept the existing login token and knowledge bases, and created new ones. After a later image switch the catalog stayed at 0.22.2 until the SQL above was run.
- **Fresh:** a fresh v0.8.3 deploy on v0.25.11 registers, logs in and creates knowledge bases, with the BM25 index in place.

## 2026-10 — WeKnora v0.8.2

- `frontend`, `app` and `docreader` run `wechatopenai/weknora-ui`, `-app` and `-docreader` `:v0.8.2` (were v0.8.0).
- Security fixes since v0.8.0 include closing cross-workspace access paths in shared spaces, rejecting path traversal in local prefixes, task IDs and wiki sort, and keeping the SSRF redirect policy on the KS3 storage client. An optional whitelist-only outbound mode (`SSRF_DNS_WHITELIST_ONLY=true`) refuses connections before DNS.
- `web/default.conf.template` and `web/api-proxy.conf` carry upstream's v0.8.2 nginx changes, on the Railway variable upstream and header maps:
  - `/embed/` pages ask the app for the channel's frame policy (`auth_request` to `/api/v1/embed-frame-policy`) and fail closed: without an enabled channel they answer 403 with `frame-ancestors 'none'`.
  - `/api/v1/local-browser/internal`, the app-to-app cluster RPC, answers 404 at the public proxy.
  - New proxied routes: `/mcp/` (upstream's public Streamable HTTP MCP endpoints, bearer-token auth), the BrowserSkill WebSocket at `/api/v1/local-browser/extension`, and the sandbox terminal/desktop WebSockets (the sandbox itself is still not part of this template).
  - The API proxy sends `Host: $http_host`, as upstream does.
- New optional `SYSTEM_SIGNING_KEY` on `app` signs embed sessions. Not needed here: without it WeKnora falls back to `SYSTEM_AES_KEY`, which the template generates, and only the key published in upstream's old `.env.example` is rejected.

### Upgrading an existing deployment

Back up Postgres and the `app` volume first. `app` migrates the schema from version 90 to 110 on its first start (forward-only) and passes `/health` afterwards. Verified locally with the template's wrappers and variables: a v0.8.0 database with a user and a knowledge base upgraded in place, the existing login token kept working, the knowledge base was listed and new ones could be created through `frontend`. A fresh v0.8.2 deploy registers, logs in and creates knowledge bases as before. Nothing to change by hand.

## 2026-09 — initial release, WeKnora v0.8.0

- Five services: `frontend` (`Dockerfile.web` over `wechatopenai/weknora-ui:v0.8.0`), `app` (`Dockerfile.app` over `wechatopenai/weknora-app:v0.8.0`), `docreader` (`Dockerfile.docreader` over `wechatopenai/weknora-docreader:v0.8.0`), `Postgres` (`paradedb/paradedb:v0.22.2-pg17`), `Redis` (Railway image).
- `web/default.conf.template` is upstream's nginx config with a dual-stack listener on `PORT`, Railway's DNS resolver, a variable upstream and header maps that keep the edge's `X-Forwarded-Proto` and strip its `X-Forwarded-For` hop; `web/entrypoint.sh` renders those and hands over to upstream's start script.
- `app-entrypoint.sh` validates `JWT_SECRET` and the 32-character `SYSTEM_AES_KEY`, binds on `[::]` and runs upstream's entrypoint. Registration is open; the system administrator is promoted through `WEKNORA_BOOTSTRAP_SYSTEM_ADMIN_EMAIL`.
- Not included: MinIO, Neo4j, alternative vector stores, SearXNG, Dex, Langfuse, MCP server, agent sandbox.
- Volumes: `Postgres`, `Redis`, `app` (`/data/files`). Healthchecks: `app` `/health`, `frontend` `/`.

### Upgrading an existing deployment

Back up Postgres and the `app` volume first. The update redeploys `frontend`, `app` and `docreader`; `app` applies migrations on its first start and only passes `/health` afterwards. Databases and their volumes are never touched.
