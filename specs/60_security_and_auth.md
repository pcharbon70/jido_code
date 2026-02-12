# 60 — Security & Auth

## Overview

Jido Code is a single-user, self-hosted application that runs on Fly Machines or locally. Security is designed around protecting the user's credentials, preventing accidental secret leakage, and providing optional access control. All secrets live in environment variables — never in source code or the database.

## Threat Model

### What We Protect
1. **API keys** (LLM providers, GitHub tokens) — most valuable, could incur costs
2. **Repository access** — GitHub App grants code read/write
3. **Execution environment** — agents can run arbitrary code
4. **Application access** — prevent unauthorized use if exposed to network

### Threat Vectors
| Threat | Mitigation |
|--------|------------|
| Unauthorized access to web UI | Optional basic auth password (env var) |
| API keys leaked in logs/output | Redaction before persistence |
| API keys sent to LLM context | Explicit exclusion in prompt construction |
| Secrets in git diffs | Pre-commit scan for secret patterns |
| Secrets in source code | All secrets are env vars; none in repo |
| Network exposure | Bind to localhost by default (local); HTTPS on Fly |
| Sprite container escape | Sprites SDK handles isolation |
| Malicious webhook payloads | Signature verification |
| GitHub App private key exposure | User-created App; key stays with user as env var |

### Explicit Non-Threats (single-user)
- Multi-user access control (no RBAC needed)
- Session hijacking (basic auth is stateless)
- CSRF on destructive actions (single-user, trusted browser)
- Data isolation between users (there's only one user)

## Authentication

### Optional Admin Password

The admin password is a simple gate on the entire application.

**Configuration**: `JIDO_CODE_ADMIN_PASSWORD` environment variable
- On Fly: `fly secrets set JIDO_CODE_ADMIN_PASSWORD=your-password`
- Locally: set in `.env` file or shell exports

**Implementation**: Phoenix `Plug.BasicAuth` in the router pipeline

```elixir
# In router.ex
pipeline :maybe_auth do
  plug JidoCode.Plugs.OptionalBasicAuth
end

# The plug checks if JIDO_CODE_ADMIN_PASSWORD env var is set
# If not set → pass through (no auth)
# If set → require basic auth (username: "admin", password: env var value)
```

**Onboarding exception**: the `/setup` route is accessible without auth (so the user can complete setup).

### No Session-Based Auth

Basic auth is stateless — credentials are sent with every request. This is appropriate because:
- Single user, single browser
- No need for session management, logout, etc.
- Works identically on Fly and local deployments

## Secrets Management

### Environment Variables — Primary Storage

All secrets are managed as environment variables. The database **never stores actual secret values**.

| Secret | Env Var | Notes |
|--------|---------|-------|
| LLM API keys | `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_AI_API_KEY` | At least one required |
| GitHub App ID | `GITHUB_APP_ID` | Numeric ID |
| GitHub App private key | `GITHUB_APP_PRIVATE_KEY` | Base64-encoded PEM |
| GitHub webhook secret | `GITHUB_WEBHOOK_SECRET` | For signature verification |
| GitHub PAT (fallback) | `GITHUB_PAT` | Alternative to GitHub App |
| Sprites API token | `SPRITES_API_TOKEN` | Phase 2 |
| Admin password | `JIDO_CODE_ADMIN_PASSWORD` | Optional |
| Phoenix secret | `SECRET_KEY_BASE` | Required (≥64 chars) |
| Database URL | `DATABASE_URL` | PostgreSQL connection |

> **Open source safety**: since users create their own GitHub App and provide their own API keys via env vars, the Jido Code source repository contains zero private keys or credentials.

### What the Database Tracks

The `Credential` resource stores **metadata only**:
- Which env vars are expected/configured
- Verification status (last successful "Test Connection")
- Provider-specific config (default model, org ID)
- **Never** the actual secret value

**Exception**: short-lived GitHub installation access tokens (1-hour expiry) may be cached in the `GithubAppInstallation` resource since they rotate frequently and have minimal security impact.

### Redaction Rules

Secrets must be redacted before:
1. **Logging**: all logger output
2. **PubSub events**: output chunks, status messages
3. **Artifact storage**: logs, transcripts, agent output
4. **Agent prompts**: never include raw secrets in LLM context
5. **Web UI display**: show only env var names, not values

**Implementation**: a `JidoCode.Secrets.Redactor` module that scans strings for known secret patterns:

```elixir
defmodule JidoCode.Secrets.Redactor do
  @patterns [
    ~r/sk-ant-[a-zA-Z0-9_-]+/,          # Anthropic
    ~r/sk-[a-zA-Z0-9_-]{20,}/,          # OpenAI
    ~r/ghp_[a-zA-Z0-9]{36}/,            # GitHub PAT
    ~r/ghs_[a-zA-Z0-9]{36}/,            # GitHub App token
    ~r/github_pat_[a-zA-Z0-9_]{22,}/,   # GitHub fine-grained PAT
  ]

  def redact(text) do
    Enum.reduce(@patterns, text, fn pattern, acc ->
      String.replace(acc, pattern, "[REDACTED]")
    end)
  end
end
```

### Secrets in Forge Sessions

When a Forge session starts:
1. Secrets are read from host env vars at runtime
2. Injected as environment variables into the session (never as files)
3. For sprites: `SpriteClient.inject_env/2`
4. For local: passed via `System.cmd/3` env option
5. The Forge output handler runs redaction on all output before broadcasting or persisting

## Network Security

### Fly Deployment (Cloud)
- HTTPS enforced via Fly's edge proxy
- Phoenix binds to internal port 4000; Fly handles TLS termination
- Admin password **strongly recommended** (publicly accessible)
- Webhook endpoint receives GitHub events directly

### Local Deployment
- Phoenix binds to `127.0.0.1:4000` by default (localhost only)
- To expose to network: user must explicitly set `PHX_HOST` and bind to `0.0.0.0`
- Admin password optional (localhost-only is sufficient protection)
- Webhooks require a tunnel (ngrok, smee.io, etc.)

### Outbound Connections
| Destination | Purpose | Protocol |
|-------------|---------|----------|
| GitHub API | Repo management, PR creation | HTTPS |
| LLM APIs | AI agent calls | HTTPS |
| Sprites API | Sandbox management | HTTPS |
| GitHub repos | git clone/push | HTTPS or SSH |

## Deployment Security Checklist

- [ ] `SECRET_KEY_BASE` is set and strong (≥64 chars)
- [ ] `JIDO_CODE_ADMIN_PASSWORD` is set (if deployed to cloud / exposed to network)
- [ ] All required env vars are set (see [61_configuration_and_deployment.md](61_configuration_and_deployment.md))
- [ ] No secrets committed to source code
- [ ] HTTPS enabled (Fly handles this; local users must configure if exposing)
- [ ] GitHub webhook secret is configured and matching
- [ ] Database credentials are not default
- [ ] `.env` file is in `.gitignore`
