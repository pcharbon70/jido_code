# 11 — Onboarding Flow

## Overview

The onboarding flow is a multi-step wizard that guides the user through initial setup on first launch. It ensures the system is properly configured before any workflows can run.

## First-Run Detection

The system detects first-run by checking:
1. Does a `SystemConfig` record exist in the database?
2. If not → redirect all routes to `/setup`
3. If yes but incomplete → redirect to `/setup` at the incomplete step
4. If complete → normal app behavior

## Wizard Steps

### Step 1: Welcome & Persistence
**Goal**: Confirm the database is working and explain what Jido Code does.

- Display welcome message and brief product description
- Database connection is already configured via `DATABASE_URL` env var
- Run a health check query to confirm PostgreSQL is connected
- Show success/failure indicator
- If database needs migration: offer a "Run Migrations" button
- **Validation**: database query succeeds

### Step 2: Admin Password (Optional)
**Goal**: Inform user about optional basic auth.

- Explain: "Since Jido Code can run on a cloud server, you may want to protect it"
- Show whether `JIDO_CODE_ADMIN_PASSWORD` env var is detected
- If detected: show "Password configured" with green checkmark
- If not: show instructions for setting the env var (Fly: `fly secrets set`, local: `.env` file)
- "Skip" button to proceed without auth
- **Note**: password is managed via env var, not stored in DB

### Step 3: LLM Provider Configuration
**Goal**: Configure at least one LLM provider so agents can function.

- Show which providers are detected from environment variables:
  - `ANTHROPIC_API_KEY` → Anthropic (primary)
  - `OPENAI_API_KEY` → OpenAI
  - `GOOGLE_AI_API_KEY` → Google AI
- Green checkmark for detected keys, red X for missing
- **"Test Connection"** button per detected provider: makes a minimal API call via `req_llm`
- At least one provider must be detected and validated
- Default model selection per provider
- If no keys detected: show instructions for setting env vars (platform-specific: Fly secrets vs local `.env`)
- **Storage**: `Credential` resource tracks which env vars are configured and verified (actual secret values stay in env vars, never in DB)
- **Validation**: test API call succeeds

### Step 4: GitHub App Connection
**Goal**: Connect a GitHub App so Jido Code can access repositories.

- **Option A: GitHub App (Recommended)**
  - User creates their own GitHub App (instructions provided with screenshots)
  - Show whether env vars are detected: `GITHUB_APP_ID`, `GITHUB_APP_PRIVATE_KEY`, `GITHUB_WEBHOOK_SECRET`
  - "Test Connection" → attempt to generate installation token
  - Display installed repos for confirmation
  - Link to GitHub App installation page for the user's App
  
- **Option B: Personal Access Token (Simpler)**
  - Show whether `GITHUB_PAT` env var is detected
  - Scope requirements listed: `repo`, `issues`, `pull_requests`
  - "Test Connection" → list accessible repos
  
- **Storage**: `Credential` resource tracks connection status, `GithubAppInstallation` resource stores installation metadata
- **Validation**: can list at least one repo

### Step 5: Default Environment
**Goal**: Choose where code runs by default.

- **Local Environment**:
  - Workspace root path input (default: `~/.jido_code/workspaces/`, or from `JIDO_CODE_WORKSPACE_ROOT` env var)
  - Validate path is writable
  - Check that `git` is available on PATH
  - Check that `claude` CLI is available (warn if not, don't block)

- **Sprite Environment** (Phase 2):
  - Show whether `SPRITES_API_TOKEN` env var is detected
  - "Test Connection" button
  - Container image selection

- **Storage**: `SystemConfig` resource
- **Validation**: path exists and is writable (local); API responds (sprite)

### Step 6: Import First Project
**Goal**: Get the user to a working state immediately.

- Show list of accessible GitHub repos (from Step 4)
- Select one or more repos to import
- Choose branch (default: repo default branch)
- Trigger clone to chosen environment
- Show progress (cloning...)
- **Validation**: clone succeeds, repo accessible in workspace

### Step 7: Complete
- Summary of configuration
- "Go to Dashboard" button
- Links to: run first workflow, read docs, configure more settings
- Mark `SystemConfig.onboarding_completed` = true

## State Machine

```
welcome → admin_password → llm_providers → github_app → environment → import_project → complete
    ↑          ↑                ↑              ↑             ↑              ↑
    └──────────┴────────────────┴──────────────┴─────────────┴──────────────┘
                              (can go back to any previous step)
```

## Data Model (setup-specific)

```elixir
# SystemConfig — singleton resource
%SystemConfig{
  onboarding_completed: boolean(),
  onboarding_step: integer(),      # last completed step
  default_environment: :local | :sprite,
  local_workspace_root: string(),
  sprites_configured: boolean(),
  inserted_at: datetime(),
  updated_at: datetime()
}
```

Note: admin password is managed via `JIDO_CODE_ADMIN_PASSWORD` env var, not stored in DB.

## UX Considerations

- Each step is a separate LiveView phase (not separate routes — keeps it simple)
- Progress bar at top showing step X of 7
- "Back" button on every step (except Welcome)
- "Skip" where appropriate (admin password, sprite config)
- Form validation is inline (no page reload)
- "Test Connection" buttons provide immediate feedback
- Error states are clear and actionable ("API key not found in environment", "Path not writable")
- Platform-aware instructions (Fly vs local)

## Open Questions

1. Should we check for Claude Code CLI installation during onboarding, or defer to first workflow run?
2. Should imported projects auto-clone during onboarding, or just register and clone on first run?
