# Deploy and Host WeKnora on Railway

WeKnora is Tencent's open-source knowledge base and agent platform. Upload PDFs, Office documents, web pages and images; WeKnora parses them (including images and tables), chunks and embeds them, and lets you chat with the knowledge, build agents with tools and skills, share workspaces with a team, and reach everything through a REST API, a CLI and IM integrations. This template deploys the upstream core stack at release v0.8.2: web UI, Go backend, document parser, ParadeDB (Postgres 17 with pgvector and pg_search) and Redis.

## About Hosting WeKnora

Hosting WeKnora on Railway means five services wired over the private network with a single public domain on the web UI. The backend runs upstream's image and applies its database migrations on every start, the parser runs as a private gRPC service and streams extracted images back inline, and the UI proxies the API while resolving the backend's address through Railway DNS so redeploys never break the link. Secrets and database credentials are generated at deploy time. Models, chunking, retrieval, agents and single sign-on are configured in WeKnora's own settings after the first login.

## Common Use Cases

- A private knowledge base for a team: upload documentation, contracts or research and ask questions with cited answers
- Agents with tools and skills over your own documents, exposed to other systems through the REST API
- Customer or employee assistants connected to IM channels such as Feishu, WeCom, DingTalk or Slack

## Dependencies for WeKnora Hosting

- A Railway account (the stack needs roughly 2 to 3 GB of memory; the parser image is 1.5 GB)
- An API key for a chat model and an embedding model (OpenAI-compatible providers, Ollama and several Chinese providers are supported), added in the UI after login

### Deployment Dependencies

- WeKnora upstream repository: https://github.com/Tencent/WeKnora
- WeKnora documentation: https://github.com/Tencent/WeKnora/tree/main/website-docs
- Template repository: https://github.com/RockinPaul/weknora_railway_template

### Implementation Details

- `frontend`: `wechatopenai/weknora-ui:v0.8.2` with a Railway-aware nginx config (DNS resolver, variable upstream, dual-stack listener), healthcheck `/`, public domain.
- `app`: `wechatopenai/weknora-app:v0.8.2`, wrapper validates `JWT_SECRET` and the 32-character `SYSTEM_AES_KEY`, binds on `[::]`, runs upstream's entrypoint; healthcheck `/health`; volume `/data/files` for uploads.
- `docreader`: `wechatopenai/weknora-docreader:v0.8.2`, gRPC on 50051, private only.
- `Postgres`: `paradedb/paradedb:v0.22.2-pg17` with a volume, required for the `pg_search` extension. `Redis`: Railway's Redis image with a volume.

First login: register on the web domain, set `WEKNORA_BOOTSTRAP_SYSTEM_ADMIN_EMAIL` on `app` to that email and redeploy `app` once to become system administrator, then add your models under Settings, Model Management.

## Why Deploy WeKnora on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying WeKnora on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
