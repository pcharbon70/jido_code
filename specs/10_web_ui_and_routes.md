# 10 — Web UI & Routes

## Information Architecture

```
/                         → Home / Dashboard (project overview)
/setup                    → Onboarding wizard (first-run only)
/projects                 → Projects list
/projects/:id             → Project detail (workspace, workflows, runs)
/projects/:id/runs/:run_id → Workflow run detail (timeline, logs, output)
/workflows                → Workflow definitions library
/agents                   → Support agents overview
/settings                 → Settings (API keys, GitHub, environment, auth)
```

## Page Descriptions

### Dashboard (`/`)
- Overview of all projects with status indicators
- Recent workflow runs with status badges
- Quick actions: "New Workflow Run", "Import Project"
- System health: connected services, API key status (detected from env vars)
- If first-run (no setup completed), redirect to `/setup`

### Onboarding Wizard (`/setup`)
- See [11_onboarding_flow.md](11_onboarding_flow.md)
- Multi-step form, one screen per step
- Progress indicator
- Skip/defer options for non-critical steps

### Projects List (`/projects`)
- Card or list view of imported projects
- Per project: name, GitHub link, environment type, last run status
- "Import Project" button → triggers GitHub repo selection
- Filter/search by name

### Project Detail (`/projects/:id`)
- **Header**: repo name, GitHub link, environment badge (local/sprite), branch
- **Tabs or sections**:
  - **Overview**: README preview, recent activity
  - **Workflows**: associated workflow definitions, "Run Workflow" button
  - **Runs**: history of workflow runs for this project
  - **Support Agents**: configured agents (Issue Bot, etc.) with enable/disable
  - **Settings**: environment config, branch defaults, secrets overrides

### Workflow Run Detail (`/projects/:id/runs/:run_id`)
- **Execution Timeline**: vertical timeline of workflow steps
  - Each step shows: name, status (pending/running/done/failed/awaiting_approval), duration, cost
  - Expandable to show agent output
- **Live Output Stream**: scrolling log output from the active Forge session
  - Color-coded by source (stdout, stderr, agent events)
  - Auto-scroll with manual override
- **Approval Gates**: inline approve/reject buttons when workflow is awaiting input
- **Artifacts Panel**: links to produced artifacts (PR URL, logs, diffs)
- **Controls**: pause, cancel, retry (where applicable)

### Workflow Definitions (`/workflows`)
- List of available workflow templates (builtin + custom)
- Per workflow: name, description, step count, last used
- "Create Workflow" (Phase 3: visual builder; MVP: link to code docs)

### Support Agents (`/agents`)
- Overview of available support agents
- Per agent: name, description, enabled project count
- Link to per-project configuration

### Settings (`/settings`)
- **LLM Providers**: detected env vars status, "Test Connection" buttons
- **GitHub**: GitHub App connection status, installed repos, re-auth button
- **Environment**: default environment type (local/sprite), local workspace root path
- **Authentication**: admin password status (set via env var)
- **Persistence**: database connection info (read-only display)

## LiveView Real-Time Requirements

| Page | PubSub Topic | Events |
|------|-------------|--------|
| Dashboard | `"jido_code:runs"` | Run started, completed, failed |
| Run Detail | `"forge:session:<id>"` | Output chunks, status changes, needs_input |
| Run Detail | `"jido_code:run:<id>"` | Step transitions, approval requests, artifacts |
| Projects | `"jido_code:projects"` | Project sync status, webhook events |

## Key UI Components

| Component | Purpose |
|-----------|---------|
| `RunTimeline` | Vertical step-by-step execution timeline |
| `OutputStream` | Scrolling live output with ANSI color support |
| `ApprovalGate` | Inline approve/reject UI for human-in-the-loop |
| `DiffViewer` | Side-by-side or unified diff display (Phase 2+) |
| `SecretsForm` | Masked input fields for API keys with test buttons |
| `RepoSelector` | GitHub repo picker (fetches from App installation) |
| `StatusBadge` | Colored status indicator (running, done, failed, etc.) |
| `CostDisplay` | LLM cost tracking per run/step |

## Layout

All pages use `<Layouts.app flash={@flash} current_scope={@current_scope}>` as the root wrapper.

Navigation sidebar:
- Dashboard
- Projects
- Workflows
- Agents
- Settings

## Authentication Flow

- If `JIDO_CODE_ADMIN_PASSWORD` env var is set: `Plug.BasicAuth` on all routes
- If not set: all routes are open (single-user, local machine assumption)
- No session-based login; basic auth is stateless per request
- The onboarding wizard is accessible without auth (chicken-and-egg: you set the password during setup)
