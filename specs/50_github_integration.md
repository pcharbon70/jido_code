# 50 — GitHub Integration

## Overview

GitHub integration is central to Jido Code. It provides the source of projects (repos), the trigger mechanism for support agents (webhooks), and the output target for workflow results (PRs, issue comments).

## Auth Model

### GitHub App (Primary) — User-Created

Jido Code is open source — **no private keys are stored in the source code**. Each user creates their own GitHub App and provides credentials via environment variables.

**Why user-created**: this keeps the open source repo clean of any secrets, gives users full control over permissions, and avoids dependency on a shared marketplace App.

**Required env vars**:
- `GITHUB_APP_ID` — the App's numeric ID
- `GITHUB_APP_PRIVATE_KEY` — the App's private key (PEM format, base64-encoded)
- `GITHUB_WEBHOOK_SECRET` — secret for webhook signature verification

**App Permissions Required**:

| Permission | Access | Purpose |
|------------|--------|---------|
| Repository contents | Read & Write | Clone repos, push branches |
| Pull requests | Read & Write | Create and update PRs |
| Issues | Read & Write | Read issues, post comments |
| Webhooks | Read | Receive events |
| Metadata | Read | List repos, get repo info |

**Setup Flow** (documented in onboarding wizard with screenshots):
1. User goes to GitHub Settings → Developer Settings → GitHub Apps → New GitHub App
2. Configures permissions, webhook URL, and events
3. Generates a private key (downloads `.pem` file)
4. Base64-encodes the key: `base64 < private-key.pem`
5. Sets env vars (`GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY`, `GITHUB_WEBHOOK_SECRET`)
6. Installs the App on their repos

**OAuth Flow (installation)**:
1. User clicks "Install GitHub App" in Jido Code settings
2. Redirect to GitHub App installation page for their App
3. User selects repos to grant access
4. GitHub redirects back with installation ID
5. Jido Code stores installation ID and fetches initial access token
6. Access tokens are short-lived (1 hour) and refreshed as needed

### Personal Access Token (Fallback)

For users who don't want to create a GitHub App:
- Set `GITHUB_PAT` env var with a classic PAT with `repo` scope
- Used directly for API calls and git auth
- Lower rate limits, broader scope (less secure)
- No webhook support (manual workflow triggers only)

## Repo Import Flow

### 1. List Available Repos
```
GET /api/v3/installation/repositories
→ Returns repos accessible to the GitHub App installation
→ Display in RepoSelector component with search/filter
```

### 2. Select & Import
- User selects one or more repos
- For each repo, create a `Project` resource:
  ```elixir
  %Project{
    github_owner: "myorg",
    github_repo: "myapp",
    github_full_name: "myorg/myapp",
    default_branch: "main",
    clone_status: :pending
  }
  ```

### 3. Clone
- Async job clones the repo to the configured workspace
- Progress reported via PubSub
- On success: `clone_status: :ready`, `local_path` set
- On failure: `clone_status: :error`, error logged

### 4. Sync
- Periodic or on-demand `git pull` to keep workspace up to date
- Triggered before each workflow run
- Conflict resolution: always `git reset --hard origin/<branch>` (workspace is ephemeral)

## Webhooks

### Setup

**Fly deployment (cloud)**: GitHub delivers webhooks directly to the public URL.
- Webhook URL: `https://your-app.fly.dev/api/github/webhooks`

**Local deployment**: requires a tunnel for webhook delivery.
- Options: ngrok, smee.io, Cloudflare Tunnel
- Webhook URL: `https://your-tunnel-url/api/github/webhooks`
- Alternative: skip webhooks entirely, use manual triggers only

**Webhook endpoint**: `POST /api/github/webhooks`

### Events to Subscribe To

| Event | Trigger | Action in Jido Code |
|-------|---------|---------------------|
| `installation.created` | App installed | Store installation, list repos |
| `installation.deleted` | App uninstalled | Deactivate projects |
| `installation_repositories.added` | Repos added to install | Make available for import |
| `installation_repositories.removed` | Repos removed | Deactivate affected projects |
| `issues.opened` | New issue | Trigger Issue Bot (if configured) |
| `issues.edited` | Issue updated | Re-triage (if configured) |
| `issue_comment.created` | New comment on issue | Pass to Issue Bot context |
| `pull_request.opened` | New PR | Trigger PR Review Bot (Phase 3) |
| `pull_request.synchronize` | PR updated (new commits) | Re-review (Phase 3) |
| `push` | Code pushed | Trigger push-based workflows (Phase 2) |

### Webhook Processing

```elixir
defmodule JidoCodeWeb.GitHubWebhookController do
  def handle(conn, params) do
    event = get_req_header(conn, "x-github-event")
    delivery_id = get_req_header(conn, "x-github-delivery")
    signature = get_req_header(conn, "x-hub-signature-256")

    with :ok <- verify_signature(conn, signature),
         :ok <- persist_delivery(delivery_id, event, params),
         :ok <- dispatch_event(event, params) do
      send_resp(conn, 200, "ok")
    end
  end
end
```

### Webhook Security
- Verify `X-Hub-Signature-256` header against `GITHUB_WEBHOOK_SECRET` env var
- Store all deliveries in `WebhookDelivery` resource for audit
- Idempotent processing (check delivery_id for duplicates)
- Rate limit webhook processing (queue if burst)

## API Client

All GitHub API calls use `Req` (the project's standard HTTP client):

```elixir
defmodule JidoCode.GitHub.Client do
  def list_repos(installation_id) do
    token = get_installation_token(installation_id)
    
    Req.get!("https://api.github.com/installation/repositories",
      headers: [
        {"authorization", "Bearer #{token}"},
        {"accept", "application/vnd.github+json"}
      ]
    )
  end

  def create_pull_request(owner, repo, params) do
    # ...
  end

  defp get_installation_token(installation_id) do
    # Generate JWT from App private key (from GITHUB_APP_PRIVATE_KEY env var)
    # Exchange for installation access token
    # Cache until expiry
  end
end
```

## Rate Limiting

| Resource | Limit | Strategy |
|----------|-------|----------|
| GitHub API (App) | 5000/hour per install | Track remaining, back off at 10% |
| GitHub API (PAT) | 5000/hour | Same |
| Webhook processing | N/A (GitHub controls) | Queue internally if needed |

## Token Refresh

GitHub App installation tokens expire after 1 hour:
1. Before any API call, check if cached token is within 5 min of expiry
2. If expiring, generate new JWT (using `GITHUB_APP_PRIVATE_KEY` env var) and request fresh installation token
3. Cache the new token with its expiry in `GithubAppInstallation` resource
4. Thread-safe refresh via GenServer or ETS-based cache

## Mapping GitHub Entities to Ash Resources

| GitHub Entity | Ash Resource | Notes |
|---------------|-------------|-------|
| Repository | `Project` | Stores owner/repo/branch |
| Installation | `GithubAppInstallation` | Cached tokens, permissions |
| Webhook delivery | `WebhookDelivery` | Audit log |
| Issue | Not persisted | Fetched on demand |
| Pull Request | `PullRequest` | Ones created by Jido Code |
| Issue analysis | `IssueAnalysis` | From Issue Bot (existing) |
