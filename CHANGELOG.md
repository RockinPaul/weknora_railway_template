# Changelog

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
