# 20 — Ash Domain Model

## Overview

Jido Code uses the Ash Framework for data modeling and persistence, backed by PostgreSQL. The domain is organized into logical domains (Ash Domains) that group related resources.

**Secrets strategy**: actual secret values (API keys, tokens) live in environment variables and are never stored in the database. The DB tracks metadata about which secrets are configured and their verification status.

## Domains

| Domain | Purpose |
|--------|---------|
| `JidoCode.Setup` | System configuration, credentials metadata, onboarding |
| `JidoCode.Projects` | GitHub repos, workspaces, project settings |
| `JidoCode.Orchestration` | Workflow definitions, runs, artifacts |
| `JidoCode.Forge` | Forge sessions, execution records, events (existing) |
| `JidoCode.GitHub` | GitHub entities, webhook deliveries (existing) |
| `JidoCode.Agents` | Support agent configurations |

## Resources

### Setup Domain

#### `SystemConfig` (singleton)
```
id              :uuid       PK
onboarding_completed  :boolean   default: false
onboarding_step       :integer   default: 0
default_environment   :atom      [:local, :sprite]
local_workspace_root  :string    default: "~/.jido_code/workspaces"
sprites_api_configured :boolean  default: false
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

Note: admin password is managed via `JIDO_CODE_ADMIN_PASSWORD` env var, not stored in DB.

#### `Credential`
Tracks which environment variable-based credentials are configured and their verification status. **Does not store actual secret values** — those live in env vars.

```
id              :uuid       PK
provider        :atom       [:anthropic, :openai, :google, :github_app, :github_pat, :sprites]
name            :string     display name
env_var_name    :string     name of the env var (e.g., "ANTHROPIC_API_KEY")
metadata        :map        provider-specific config (e.g., default model, org_id)
verified_at     :utc_datetime  last successful test
status          :atom       [:active, :invalid, :expired, :not_set]
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

#### `GithubAppInstallation`
The App private key lives in the `GITHUB_APP_PRIVATE_KEY` env var. Short-lived installation access tokens (1-hour expiry) can be cached here since they rotate frequently.

```
id              :uuid       PK
installation_id :integer    GitHub App installation ID
account_login   :string     GitHub user/org login
account_type    :atom       [:user, :organization]
cached_access_token :string short-lived, rotates every hour
token_expires_at :utc_datetime
permissions     :map        granted permissions
repository_selection :atom  [:all, :selected]
selected_repos  :list       list of repo full_names (if selected)
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### Projects Domain

#### `Project`
```
id              :uuid       PK
name            :string     display name
github_owner    :string     repo owner (user or org)
github_repo     :string     repo name
github_full_name :string    "owner/repo"
default_branch  :string     default: "main"
environment_type :atom      [:local, :sprite]
local_path      :string     nullable, absolute path to cloned repo
sprite_spec     :map        nullable, sprite configuration
clone_status    :atom       [:pending, :cloning, :ready, :error]
last_synced_at  :utc_datetime
settings        :map        project-specific overrides
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

Relationships:
- `has_many :workflow_runs`
- `has_many :support_agent_configs`
- `has_many :pull_requests`

#### `ProjectSecret`
Tracks project-specific environment variables to inject into workspaces. **Does not store actual values** — those come from env vars or are set at runtime.

```
id              :uuid       PK
project_id      :uuid       FK → Project
key             :string     env var name (e.g., "DATABASE_URL")
env_var_name    :string     source env var name (nullable, if mapped from a global env var)
configured      :boolean    whether the value is available
inject_to_env   :boolean    default: true (inject into workspace env)
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### Orchestration Domain

#### `WorkflowDefinition`
```
id              :uuid       PK
name            :string     unique name/slug
display_name    :string     human-readable name
description     :string
category        :atom       [:builtin, :custom]
version         :integer    default: 1
definition      :map        serialized Runic DAG definition
input_schema    :map        expected inputs (JSON Schema-like)
default_inputs  :map        default values for inputs
triggers        :list       trigger types [:manual, :webhook, :schedule]
approval_required :boolean  default: true (per-workflow configurable)
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

#### `WorkflowRun`
```
id              :uuid       PK
project_id      :uuid       FK → Project
workflow_definition_id :uuid FK → WorkflowDefinition
status          :atom       [:pending, :running, :awaiting_approval, :completed, :failed, :cancelled]
trigger         :atom       [:manual, :webhook, :schedule, :support_agent]
trigger_metadata :map       who/what triggered it
inputs          :map        runtime inputs
current_step    :string     current DAG node ID
step_results    :map        accumulated results per step
error           :string     nullable, error message
started_at      :utc_datetime
completed_at    :utc_datetime
total_cost_usd  :decimal    accumulated LLM costs
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

Relationships:
- `belongs_to :project`
- `belongs_to :workflow_definition`
- `has_many :artifacts`
- `has_one :pull_request`
- `has_many :forge_sessions` (via join or reference)

#### `Artifact`
```
id              :uuid       PK
workflow_run_id :uuid       FK → WorkflowRun
type            :atom       [:log, :diff, :report, :transcript, :pr_url, :cost_summary, :research_doc, :design_doc, :prompt_file]
name            :string     display name
content_type    :string     MIME type
content         :text       inline content (for small artifacts)
file_path       :string     nullable, path to file (for large artifacts)
metadata        :map        type-specific metadata
inserted_at     :utc_datetime
```

#### `PullRequest`
```
id              :uuid       PK
project_id      :uuid       FK → Project
workflow_run_id :uuid       FK → WorkflowRun, nullable
github_pr_number :integer
github_pr_url   :string
branch_name     :string
title           :string
body            :text
status          :atom       [:open, :merged, :closed]
created_at      :utc_datetime
merged_at       :utc_datetime  nullable
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### Agents Domain

#### `SupportAgentConfig`
```
id              :uuid       PK
project_id      :uuid       FK → Project
agent_type      :atom       [:github_issue_bot, :pr_review_bot, :dependency_bot]
enabled         :boolean    default: false
configuration   :map        agent-specific config (e.g., auto-respond, labels to watch)
webhook_events  :list       GitHub events to listen for
last_triggered_at :utc_datetime
inserted_at     :utc_datetime
updated_at      :utc_datetime
```

### Existing Forge Domain (carried forward)

These resources already exist in the codebase and are carried forward with namespace updates:

- `Session` — Forge session metadata
- `ExecSession` — per-command execution records
- `Event` — append-only event log
- `Checkpoint` — session snapshots
- `Workflow` — stored workflow definitions (Forge-level)
- `SpriteSpec` — sprite configuration catalog

### Existing GitHub Domain (carried forward)

- `Repo` — GitHub repo metadata
- `WebhookDelivery` — webhook event records
- `IssueAnalysis` — issue triage/research results

## Secrets Strategy

Actual secret values (API keys, tokens, private keys) are **never stored in the database**. They are managed as environment variables:

- **Fly deployment**: `fly secrets set KEY=value`
- **Local deployment**: `.env` file (gitignored) or shell exports
- **The DB tracks metadata only**: which env vars are expected, whether they've been verified, and provider-specific configuration (like default model selection)
- **Short-lived tokens** (GitHub installation access tokens, 1-hour expiry) may be cached in the DB since they rotate frequently and have minimal security impact

This approach:
- Keeps secrets out of the database entirely
- Works naturally with Fly's secrets management
- Avoids the complexity of Cloak/encrypted fields for MVP
- Means the open source repo contains zero private keys or credentials

## Retention Policy

| Resource | Retention |
|----------|-----------|
| WorkflowRun | Indefinite (user manages) |
| Artifact (logs) | 30 days default, configurable |
| Forge Event | 7 days default, configurable |
| WebhookDelivery | 30 days |
| Credential | Until deleted by user |

## Indexes

Key indexes for query performance:
- `WorkflowRun`: `(project_id, status)`, `(project_id, inserted_at DESC)`
- `Artifact`: `(workflow_run_id, type)`
- `PullRequest`: `(project_id, status)`, `(github_pr_number)` unique per project
- `Credential`: `(provider)` unique
- `Project`: `(github_full_name)` unique
