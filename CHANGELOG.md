# Changelog

## 2026-09 — initial release, WeKnora v0.8.0

- Five services: `frontend` (`Dockerfile.web` over `wechatopenai/weknora-ui:v0.8.0`), `app` (`Dockerfile.app` over `wechatopenai/weknora-app:v0.8.0`), `docreader` (`Dockerfile.docreader` over `wechatopenai/weknora-docreader:v0.8.0`), `Postgres` (`paradedb/paradedb:v0.22.2-pg17`), `Redis` (Railway image).
- `web/default.conf.template` is upstream's nginx config with a dual-stack listener on `PORT`, Railway's DNS resolver and a variable upstream; `web/entrypoint.sh` renders those and hands over to upstream's start script.
- `app-entrypoint.sh` validates `JWT_SECRET` and the 32-character `SYSTEM_AES_KEY`, binds on `::` and runs upstream's entrypoint. Registration is open; the system administrator is promoted through `WEKNORA_BOOTSTRAP_SYSTEM_ADMIN_EMAIL`.
- Not included: MinIO, Neo4j, alternative vector stores, SearXNG, Dex, Langfuse, MCP server, agent sandbox.
- Volumes: `Postgres`, `Redis`, `app` (`/data/files`). Healthchecks: `app` `/health`, `frontend` `/`.

### Upgrading an existing deployment

Back up Postgres and the `app` volume first. The update redeploys `frontend`, `app` and `docreader`; `app` applies migrations on its first start and only passes `/health` afterwards. Databases and their volumes are never touched.
