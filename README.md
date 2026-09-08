# WeKnora Railway Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/weknora?referralCode=YqmMB-&utm_medium=integration&utm_source=template&utm_campaign=generic)

Railway template for [WeKnora](https://github.com/Tencent/WeKnora), Tencent's open-source (MIT) knowledge base and agent platform: upload documents, get them parsed, chunked and embedded, then chat with them, build agents with tools and skills, share workspaces with a team, and expose everything through a REST API, MCP server and IM integrations. It deploys the upstream core stack at a pinned release:

| Service | Runs | Source |
|---|---|---|
| `frontend` | the web UI and the only public entry point; proxies `/api/`, `/files` and `/r/` to the app | `Dockerfile.web` over `wechatopenai/weknora-ui:v0.8.0` |
| `app` | Go backend, migrations, background jobs; uploads live on its volume | `Dockerfile.app` over `wechatopenai/weknora-app:v0.8.0` |
| `docreader` | document parser (PDF, Office, HTML, images) behind gRPC, private only | `Dockerfile.docreader` over `wechatopenai/weknora-docreader:v0.8.0` |
| `Postgres` | metadata, vectors and full-text index | `paradedb/paradedb:v0.22.2-pg17` (Postgres 17 with pgvector and pg_search, which WeKnora's migrations require) |
| `Redis` | queue and streaming | Railway's Redis image |

Not included: MinIO, Neo4j graph RAG, the alternative vector stores, SearXNG, Dex, Langfuse and the agent sandbox (it needs a Docker socket). All are optional upstream and can be added as separate services later; the variables they need are documented in upstream's `.env.example`.

## First login

1. Open the `frontend` domain and register. Registration is open by default and the first account gets its own workspace.
2. Make that account the system administrator: set `WEKNORA_BOOTSTRAP_SYSTEM_ADMIN_EMAIL` on `app` to the email you registered with (you can set it before the first deploy) and redeploy `app`. WeKnora promotes the user at startup, only while the deployment has no system administrator yet; until the account exists the log says "no matching user (will retry on next restart)".
3. Sign in again. As system administrator, open Settings, Model Management and add your chat, embedding and, optionally, rerank and vision models (OpenAI-compatible endpoints, Ollama and several Chinese providers are supported). Nothing works without an embedding and a chat model.
4. Optional: close registration with `DISABLE_REGISTRATION=true` on `app` (new users then join by invitation link), or switch it in Settings, System.

## Variables

`app`:

| Variable | Default | Purpose |
|---|---|---|
| `JWT_SECRET` | generated (64 chars) | Signs login tokens. Changing it logs everyone out. |
| `SYSTEM_AES_KEY` | generated (32 chars) | Encrypts stored credentials such as model API keys. Must be exactly 32 characters, the wrapper refuses to start otherwise. Changing it makes stored credentials unreadable. |
| `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME` | refs to `Postgres` | ParadeDB connection. |
| `REDIS_ADDR`, `REDIS_PASSWORD` | refs to `Redis` | `host:port` and password. |
| `DOCREADER_ADDR` | `${{docreader.RAILWAY_PRIVATE_DOMAIN}}:50051` | gRPC parser. |
| `APP_EXTERNAL_URL`, `FRONTEND_BASE_URL` | `https://${{frontend.RAILWAY_PUBLIC_DOMAIN}}` | Absolute links in invitations, share links and IM channels. |
| `WEKNORA_BOOTSTRAP_SYSTEM_ADMIN_EMAIL` | empty | Email to promote to system administrator at startup. |
| `MAX_FILE_SIZE_MB` | `50` | Upload limit, shared with `frontend` and `docreader` by reference. |
| `DISABLE_REGISTRATION` | `false` | `true` forces invite-only registration. |
| `LOG_LEVEL` | `info` | |
| `WEKNORA_LANGUAGE` | `en-US` (image default) | Backend language for generated content; `zh-CN` upstream. |

`frontend`: `APP_HOST=${{app.RAILWAY_PRIVATE_DOMAIN}}`, `APP_PORT=8080`, `APP_SCHEME=http`, `DEFAULT_LOCALE=en-US`, `MAX_FILE_SIZE_MB=${{app.MAX_FILE_SIZE_MB}}`, `PORT=80`. `docreader`: `MAX_FILE_SIZE_MB=${{app.MAX_FILE_SIZE_MB}}`, `LOG_LEVEL=info`. `Postgres`: `POSTGRES_USER=postgres`, `POSTGRES_PASSWORD` generated, `POSTGRES_DB=weknora`, `PGDATA=/var/lib/postgresql/data/pgdata`. `Redis`: Railway's standard variables.

Everything else (models, chunking, retrieval, agents, SSO, IM channels) is configured in the UI or through upstream's environment variables, which pass straight through to the unchanged upstream images.

## How it fits together

- `app` runs upstream's image with a small wrapper: it checks the secrets, sets `SERVER_HOST=::` so the Go server listens on IPv4 and IPv6 for Railway's private network, and then runs upstream's own entrypoint, which hands the upload volume to the unprivileged `appuser` and starts the server. Migrations run automatically (`AUTO_MIGRATE=true`). Healthcheck `/health`.
- `frontend` keeps upstream's nginx config, with three changes: it listens on `PORT`, it resolves the app's address through Railway's DNS on every request instead of once at startup (so it survives `app` redeploys), and all proxy targets use that variable upstream. Upstream's start script still renders upload limits and locale into the page.
- `docreader` is upstream's image with a pinned tag. Extracted images travel inline over gRPC, so no shared volume between `app` and `docreader` is needed. It has no HTTP endpoint, so no Railway healthcheck.
- Client addresses: WeKnora trusts private-network proxies by default (`WEKNORA_TRUSTED_PROXIES` to change). Railway's edge appends its own address to `X-Forwarded-For`, which Gin's default resolution handles by taking the first entry.
- Sizing: upstream's Helm defaults are 1 GiB for `app`, 512 MiB each for `docreader` and Postgres. Parsing large PDFs is the memory hot spot; raise `docreader` first if parsing fails. The `docreader` image is 1.5 GB compressed, so its first deploy takes a few minutes.

## Upgrading WeKnora

Bump the tag in `Dockerfile.app`, `Dockerfile.web` and `Dockerfile.docreader` together; upstream releases the three images as one version. Then diff `web/default.conf.template` against upstream's `frontend/nginx.conf` and carry over new locations. Merging to `main` notifies everyone who deployed the template. Migrations apply on the next `app` start; back up Postgres and the `app` volume first, as upstream recommends. Note breaking changes in `CHANGELOG.md`.

## Files

- `Dockerfile.app`, `app-entrypoint.sh`: backend wrapper
- `Dockerfile.web`, `web/default.conf.template`, `web/entrypoint.sh`: UI with the Railway-aware nginx config
- `Dockerfile.docreader`: pinned parser image
- `TEMPLATE_OVERVIEW.md`: the marketplace description
- `CHANGELOG.md`: what changed and how to upgrade an existing deployment
