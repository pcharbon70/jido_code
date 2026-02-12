# 61 — Configuration & Deployment

## Overview

Jido Code runs in two modes: as a cloud service on a Fly Machine, or as a local Phoenix app on a developer's machine. Configuration is primarily through environment variables. No secrets are stored in the source code.

## Deployment Modes

### Cloud Mode (Fly Machine) — Primary
- Deployed as a Fly Machine with attached PostgreSQL
- Publicly accessible (with admin password required)
- GitHub webhooks delivered directly to the public URL
- Workspaces use Sprites (cloud sandboxes) by default
- Can also mount persistent volumes for local-style workspaces

### Local Mode
- `mix phx.server` on the developer's machine
- PostgreSQL running locally (or via Docker)
- Bound to `localhost:4000` by default
- GitHub webhooks require a tunnel (ngrok, smee.io, Cloudflare Tunnel)
- Workspaces use local filesystem
- Coding CLIs (Claude Code, Ampcode) must be installed on the host

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `SECRET_KEY_BASE` | Phoenix secret key (≥64 chars) | `mix phx.gen.secret` |
| `DATABASE_URL` | PostgreSQL connection string | `postgres://user:pass@host/jido_code` |
| `PHX_HOST` | Hostname for URL generation | `jido-code.fly.dev` or `localhost` |

### LLM Providers

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Anthropic API key for Claude models |
| `OPENAI_API_KEY` | OpenAI API key (optional) |
| `GOOGLE_AI_API_KEY` | Google AI API key (optional) |

### GitHub

| Variable | Description |
|----------|-------------|
| `GITHUB_APP_ID` | GitHub App ID (user creates their own App) |
| `GITHUB_APP_PRIVATE_KEY` | GitHub App private key (PEM format, base64-encoded) |
| `GITHUB_WEBHOOK_SECRET` | Webhook signature verification secret |
| `GITHUB_PAT` | Personal Access Token (fallback, alternative to App) |

### Sprites (Cloud Sandboxes)

| Variable | Description |
|----------|-------------|
| `SPRITES_API_TOKEN` | Sprites SDK API token |
| `SPRITES_API_URL` | Sprites API endpoint (if non-default) |

### Application

| Variable | Description | Default |
|----------|-------------|---------|
| `JIDO_CODE_ADMIN_PASSWORD` | Admin password for basic auth | *(none — no auth)* |
| `JIDO_CODE_WORKSPACE_ROOT` | Local workspace root directory | `~/.jido_code/workspaces` |
| `JIDO_CODE_DEFAULT_ENV` | Default environment type (`local` or `sprite`) | `local` |
| `PORT` | HTTP port | `4000` |
| `PHX_SERVER` | Start the Phoenix server | `true` |
| `POOL_SIZE` | Database connection pool size | `10` |

## Configuration Files

### `config/runtime.exs` — Primary Configuration

All environment-dependent config reads from env vars at runtime:

```elixir
config :jido_code, JidoCode.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

config :jido_code, JidoCodeWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST", "localhost")],
  http: [port: String.to_integer(System.get_env("PORT", "4000"))],
  secret_key_base: System.get_env("SECRET_KEY_BASE")

config :jido_code, :github,
  app_id: System.get_env("GITHUB_APP_ID"),
  private_key: System.get_env("GITHUB_APP_PRIVATE_KEY") |> maybe_decode_base64(),
  webhook_secret: System.get_env("GITHUB_WEBHOOK_SECRET"),
  pat: System.get_env("GITHUB_PAT")

config :jido_code, :llm,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY"),
  openai_api_key: System.get_env("OPENAI_API_KEY"),
  google_ai_api_key: System.get_env("GOOGLE_AI_API_KEY")

config :jido_code, :auth,
  admin_password: System.get_env("JIDO_CODE_ADMIN_PASSWORD")

config :jido_code, :workspace,
  root: System.get_env("JIDO_CODE_WORKSPACE_ROOT", "~/.jido_code/workspaces"),
  default_env: String.to_atom(System.get_env("JIDO_CODE_DEFAULT_ENV", "local"))
```

### No `.env` Files in Source

The repository ships with:
- `.env.example` — documents all env vars with placeholder values
- `.env` is in `.gitignore` — never committed
- No GitHub App private keys, API keys, or secrets in the source

## Fly Deployment

### `fly.toml`

```toml
app = "jido-code"
primary_region = "iad"

[build]
  dockerfile = "Dockerfile"

[env]
  PHX_HOST = "jido-code.fly.dev"
  PHX_SERVER = "true"
  JIDO_CODE_DEFAULT_ENV = "sprite"

[http_service]
  internal_port = 4000
  force_https = true

[[vm]]
  size = "shared-cpu-2x"
  memory = "1gb"
```

### Fly Secrets

```bash
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set DATABASE_URL=postgres://...
fly secrets set ANTHROPIC_API_KEY=sk-ant-...
fly secrets set GITHUB_APP_ID=12345
fly secrets set GITHUB_APP_PRIVATE_KEY=$(base64 < private-key.pem)
fly secrets set GITHUB_WEBHOOK_SECRET=whsec_...
fly secrets set JIDO_CODE_ADMIN_PASSWORD=...
fly secrets set SPRITES_API_TOKEN=...
```

### Fly PostgreSQL

```bash
fly postgres create --name jido-code-db
fly postgres attach jido-code-db
```

## Local Development Setup

### Prerequisites
- Elixir 1.18+
- PostgreSQL 14+
- Node.js (for asset compilation)
- `git` on PATH
- `claude` CLI (optional, for Claude Code runner)

### Quick Start

```bash
git clone https://github.com/agentjido/jido_code.git
cd jido_code

# Copy and edit environment
cp .env.example .env
# Edit .env with your API keys

# Install dependencies and setup database
source .env
mix setup

# Start the server
mix phx.server
```

### `.env.example`

```bash
# Required
export SECRET_KEY_BASE="generate-with-mix-phx-gen-secret"
export DATABASE_URL="postgres://postgres:postgres@localhost/jido_code_dev"

# LLM Providers (at least one required)
export ANTHROPIC_API_KEY=""
# export OPENAI_API_KEY=""
# export GOOGLE_AI_API_KEY=""

# GitHub (choose App or PAT)
# Option A: GitHub App (recommended)
# export GITHUB_APP_ID=""
# export GITHUB_APP_PRIVATE_KEY=""  # base64-encoded PEM
# export GITHUB_WEBHOOK_SECRET=""

# Option B: Personal Access Token
# export GITHUB_PAT=""

# Optional
# export JIDO_CODE_ADMIN_PASSWORD=""
# export JIDO_CODE_WORKSPACE_ROOT="~/.jido_code/workspaces"
# export JIDO_CODE_DEFAULT_ENV="local"
# export SPRITES_API_TOKEN=""
```

## GitHub App Setup (User's Responsibility)

Since Jido Code is open source, each user creates their own GitHub App:

### Steps

1. Go to GitHub Settings → Developer Settings → GitHub Apps → New GitHub App
2. Configure:
   - **App name**: "My Jido Code" (or any unique name)
   - **Homepage URL**: your Jido Code instance URL
   - **Webhook URL**: `https://your-instance.fly.dev/api/github/webhooks`
   - **Webhook secret**: generate a random secret
   - **Permissions**:
     - Repository: Contents (Read & Write), Pull Requests (Read & Write), Issues (Read & Write), Metadata (Read)
   - **Events**: Issues, Pull Request, Push
3. Generate a private key (downloads a `.pem` file)
4. Base64-encode the private key: `base64 < your-key.pem`
5. Set the env vars: `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY`, `GITHUB_WEBHOOK_SECRET`
6. Install the App on your repos

### Documentation

The Jido Code README and onboarding wizard will include step-by-step instructions with screenshots for creating and configuring a GitHub App.

## Database Migrations

### First Run
```bash
mix ecto.create
mix ecto.migrate
```

### Fly
```bash
fly ssh console -C "/app/bin/jido_code eval 'JidoCode.Release.migrate()'"
```

### Migration Strategy
- All migrations are reversible where possible
- Migrations are run automatically on Fly deploy (via release module)
- Local dev: manual `mix ecto.migrate`

## Health Check

`GET /healthz` — returns 200 if the app is running and database is connected. Used by Fly for health checks.

## Monitoring

- Phoenix LiveDashboard available at `/dev/dashboard` (dev only by default)
- Fly metrics via `fly metrics`
- Application telemetry via `:telemetry` (standard Phoenix)
- Future: Jido LiveDashboard integration for agent observability
