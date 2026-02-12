# Current Status (verified against codebase)

> Snapshot: 2026-02-11

This document is a **fact-checked snapshot** of what exists in the Jido Code repository today, compared against the PRD and specs. Verified facts only, no aspirational claims.

---

## Executive Summary

| Area | Status |
|------|--------|
| **Forge** (sandbox execution) | ✅ Production-quality OTP subsystem with streaming UI |
| **GitHub Issue Bot** (agents) | ✅ Substantial multi-agent Jido showcase with tests |
| **GitHub domain** (Ash resources) | 🟡 Resources + sensor exist; webhook_secret stored in DB |
| **Folio** (GTD demo) | ✅ Working demo; **not** the "Projects" domain from specs |
| **Auth** | 🟡 AshAuthentication works; differs from spec's BasicAuth model |
| **Onboarding / setup wizard** | ❌ Not started |
| **Runic workflows** | ❌ Not started |
| **Git + PR automation** | ❌ Not started |
| **Product loop** (import → run → approve → ship) | ❌ Not started |

---

## What Exists (by subsystem)

### 1. Forge — Sandbox Execution Engine ✅

The most complete subsystem. 21 backend files + 3 LiveViews + architecture doc.

**Backend modules:**

| Module | Purpose |
|--------|---------|
| `JidoCode.Forge` | Public API facade |
| `Forge.Manager` | Lifecycle GenServer; DynamicSupervisor + Registry; concurrency limits (50 total, per-runner) |
| `Forge.SpriteSession` | Per-session GenServer: provision → bootstrap → init runner → iterate → input → cleanup |
| `Forge.Runner` | Behaviour with callbacks: `init`, `run_iteration`, `apply_input`, `handle_output`, `terminate` |
| `Forge.Runners.ClaudeCode` | Claude Code CLI runner; `--output-format stream-json` parsing; directory/template setup |
| `Forge.Runners.Shell` | Shell command runner |
| `Forge.Runners.Workflow` | Data-driven step runner (**not** Runic) |
| `Forge.Runners.Custom` | User-provided runner |
| `Forge.SpriteClient` | Behaviour abstraction |
| `Forge.SpriteClient.Fake` | Dev/test fake client |
| `Forge.SpriteClient.Live` | Real Sprites SDK client |
| `Forge.Operations` | resume, cancel, checkpoint, complete, mark_failed orchestration |
| `Forge.Persistence` | Records session events to Ash resources |
| `Forge.PubSub` | `forge:sessions` and `forge:session:<id>` topics |
| `Forge.Bootstrap` | Runs bootstrap steps in sprite |
| `Forge.Domain` | Ash domain: Session, SpriteSpec, Workflow, ExecSession, Event, Checkpoint |

**LiveView UI:**

| View | Route | Description |
|------|-------|-------------|
| `Forge.IndexLive` | `/forge` | Session list |
| `Forge.NewLive` | `/forge/new` | Session creation form |
| `Forge.ShowLive` | `/forge/:session_id` | Terminal UI: streaming output, iteration controls, input prompts, colocated JS hooks |

**API surface:**
- `start_session/2`, `stop_session/2`, `exec/3`, `cmd/4`
- `run_loop/2`, `run_iteration/2`, `apply_input/2`
- `resume/1`, `cancel/1`, `create_checkpoint/2`

**Known limitations:**
- Checkpoint/resume: sprite-level checkpointing is stubbed (generates placeholder IDs)
- Not yet connected to product concepts (Projects, Workspaces, Workflows, Artifacts)
- No secrets redaction on output streams

---

### 2. GitHub Issue Bot — Multi-Agent Showcase ✅

24 files implementing a complete issue lifecycle pipeline.

**Agent architecture:**
```
CoordinatorAgent
  │
  ├── TriageAgent + TriageAction
  │
  ├── ResearchCoordinator
  │     ├── CodeSearchAgent + CodeSearchAction
  │     ├── PRSearchAgent + PRSearchAction
  │     ├── ReproductionAgent + ReproductionAction
  │     └── RootCauseAgent + RootCauseAction
  │
  └── PullRequestCoordinator
        ├── PatchAgent + PatchAction
        ├── QualityAgent + QualityAction
        └── PRSubmitAgent + PRSubmitAction
```

**Patterns demonstrated:**
- Jido agents with `signal_routes`
- Fan-out parallel workers
- Coordinator → worker delegation
- Signal-based communication

**Test coverage:** 3 test files (coordinator, research coordinator, PR coordinator)

**Not integrated:** The bot is agent code only. No UI wiring, no end-to-end webhook → workspace → Forge → PR pipeline.

---

### 3. GitHub Domain 🟡

4 files with Ash resources and a Jido sensor.

| Resource | Data Layer | Purpose |
|----------|-----------|---------|
| `GitHub.Repo` | AshPostgres | Repo tracking with owner/name/full_name/enabled/settings |
| `GitHub.WebhookDelivery` | AshPostgres | Persisted webhook payloads |
| `GitHub.IssueAnalysis` | AshPostgres | Persisted issue analyses |
| `GitHub.WebhookSensor` | — | Polls pending deliveries, emits Jido signals |

**`GitHub.Repo` code interface:** `create`, `read`, `get_by_id`, `get_by_full_name`, `update`, `disable`, `enable`, `list_enabled`

**⚠️ `webhook_secret` is stored in the database** (marked `sensitive?` but persisted). The spec says secrets should stay in env vars only.

---

### 4. Folio — GTD Task Manager Demo ✅

**Important:** This is a **GTD (Getting Things Done) task manager**, not the "Projects" domain described in the specs.

| Resource | Data Layer | Purpose |
|----------|-----------|---------|
| `Folio.Project` | **ETS** (not Postgres) | GTD multi-step outcomes (active/someday/done/dropped) |
| `Folio.InboxItem` | ETS | GTD inbox items |
| `Folio.Action` | ETS | GTD next actions |

**Agent:** `Folio.FolioAgent` — `Jido.AI.ReActAgent` with ~15 tools, `model: :fast`, `max_iterations: 8`

**UI:** `FolioLive` — 655-line chat-based GTD interface with agent state polling

---

### 5. Accounts / Authentication 🟡

| Resource | Purpose |
|----------|---------|
| `Accounts.User` | AshAuthentication: password + magic link + API key strategies |
| `Accounts.Token` | Auth tokens |
| `Accounts.ApiKey` | API key management |

Plus 3 email senders (confirmation, magic link, password reset).

**⚠️ Mismatch vs specs:** The PRD describes "single-user, optional admin password via env var, no registration." The codebase has full AshAuthentication with registration, sign-in, password reset, magic link, and API keys.

---

### 6. Web Layer

**Verified routes:**

| Route | View | Status |
|-------|------|--------|
| `/` | `HomeLive` | Shows "Agent Jido" branding; redirects to `/dashboard` if logged in |
| `/dashboard` | `DashboardLive` | **20-line stub** |
| `/settings/:tab?` | `SettingsLive` | GitHub tab manages repos via AshPhoenix.Form; Agents + Account tabs are "coming soon" stubs |
| `/forge` | `Forge.IndexLive` | Session list |
| `/forge/new` | `Forge.NewLive` | Session creation |
| `/forge/:session_id` | `Forge.ShowLive` | Terminal UI |
| `/folio` | `FolioLive` | GTD demo |
| `/demos/chat` | `Demos.ChatLive` | Chat demo (684 lines) |
| `/api/json/*` | AshJsonApi + SwaggerUI | JSON:API endpoints |
| `/status` | HeartbeatPlug | Health check |
| `/dev/dashboard` | LiveDashboard | Dev only |
| `/admin` | AshAdmin | Dev only |

**Auth routes:** `/sign-in`, `/register`, `/reset`, `/auth/*`, `/sign-out`, magic link, confirm

**UI components:** ~90 Mishka Chelekom components installed

---

### 7. Infrastructure

- `JidoCode.Jido` — Jido runtime instance (`use Jido, otp_app: :jido_code`)
- Supervision tree: Telemetry, Repo, PubSub, Jido, Endpoint, AshAuth, Registry, 2× DynamicSupervisor, Forge.Manager, Fake sprite client (dev)
- `JidoCode.Secrets` — handles only AshAuthentication token signing secret

---

### 8. Tests & Migrations

**Tests (9 files):**
- `coordinator_test.exs` — Issue Bot coordinator
- `research_coordinator_test.exs` — Issue Bot research
- `pull_request_coordinator_test.exs` — Issue Bot PR
- `sprite_integration_test.exs` — Forge sprite
- `error_html_test.exs`, `error_json_test.exs`, `page_controller_test.exs` — controllers
- `chat_live_test.exs` — chat demo

**No tests for:** Forge LiveViews, FolioLive, SettingsLive, DashboardLive, any Ash resources, Accounts domain.

**Migrations (5):**
1. Auth resources init
2. Auth strategies (password, magic link, API key)
3. GitHub domain
4. Forge resources
5. Forge v2 resources

---

## Gap Analysis vs PRD/Spec Requirements

| Requirement | Spec Says | Code Has | Gap |
|---|---|---|---|
| **R1: Single-user auth** | Optional admin password via env var; no registration | AshAuthentication with registration + password + magic link + API key | Auth model mismatch |
| **R2: Onboarding wizard** | 7-step first-run wizard; SystemConfig resource | Nothing | Not started |
| **R3: GitHub App integration** | User-created App; env-var secrets; no secrets in DB | GitHub.Repo with webhook_secret in DB; no App JWT/token flow | Partial; secrets strategy mismatch |
| **R4: Project import + environments** | Clone repos; uniform Workspace interface | Forge runs commands in sprites; no repo import/clone flow | Not started |
| **R5: Durable workflows (Runic)** | Runic DAG workflows; WorkflowDefinition/Run/Artifact resources | No Runic integration; Forge.Runners.Workflow is data-driven steps, not Runic | Not started |
| **R6: AI agent orchestration** | Workflows orchestrate agents; Claude Code runner for MVP | Claude Code runner in Forge ✅; Issue Bot agents exist but not UI-driven | Partial |
| **R7: Commit + PR automation** | Auto branch, commit, push, open PR | Nothing in the web app | Not started |
| **R8: Support agents (webhooks)** | Webhooks trigger Issue Bot | WebhookSensor emits signals; Issue Bot exists; no end-to-end wiring | Partial |
| **R9: Real-time observability** | Streaming output in UI | Forge UI streams output via PubSub ✅ | Met (for Forge) |
| **R10: OSS showcase** | Demonstrate idiomatic Jido patterns | Forge + Issue Bot are strong showcases ✅ | Met |
| **R11: Dual deployment** | Fly + local via env vars | Standard Phoenix app; .env.example is incomplete | Partial |

---

## Specific Mismatches That Need Decisions

### A. Auth Model ⚠️
- **Spec:** `Plug.BasicAuth` gated by `JIDO_CODE_ADMIN_PASSWORD` env var. No user registration.
- **Code:** Full AshAuthentication with `/register`, `/sign-in`, `/reset`, magic link, API keys.
- **Decision needed:** Simplify to spec model, or update specs to accept AshAuthentication.

### B. Secrets Strategy ⚠️
- **Spec:** Secrets in env vars only. DB stores metadata. Centralized Redactor module.
- **Code:** `GitHub.Repo.webhook_secret` persisted in Postgres. No redaction anywhere.
- **Decision needed:** Migrate to env-var-only, or accept DB storage with encryption (AshCloak is in deps).

### C. Folio vs Projects ⚠️
- **Spec:** "Project" = a GitHub repository imported into Jido Code with workspace, environment, and workflow runs.
- **Code:** `Folio.Project` = a GTD multi-step outcome on ETS. Completely different concept.
- **Decision needed:** Build the spec's Projects domain separately, or evolve Folio.

### D. Naming / Branding
- Homepage renders "Agent Jido" — specs say "Jido Code"
- Health endpoint is `/status` — specs say `/healthz`
- `.env.example` doesn't document most required env vars

---

## Not Started (by spec area)

### Onboarding (specs 11, 20)
- [ ] `SystemConfig` resource (singleton, tracks setup state)
- [ ] `Credential` resource (env var metadata, no secret values)
- [ ] `GithubAppInstallation` resource
- [ ] `/setup` LiveView wizard
- [ ] First-run detection + redirect

### Orchestration (specs 30, 31, 32)
- [ ] `WorkflowDefinition` resource
- [ ] `WorkflowRun` resource
- [ ] `Artifact` resource
- [ ] `PullRequest` resource
- [ ] Runic DAG integration
- [ ] "Implement Task" builtin workflow
- [ ] "Fix Failing Tests" builtin workflow
- [ ] Approval gate UI

### Project Import + Workspaces (specs 40, 50)
- [ ] Repo list/import flow (GitHub API)
- [ ] Clone pipeline
- [ ] Workspace behaviour (9 callbacks per spec)
- [ ] Local workspace implementation
- [ ] Sprite workspace implementation

### Git + PR Automation (spec 51)
- [ ] Branch creation
- [ ] Conventional commits
- [ ] Push to remote
- [ ] PR creation via GitHub API
- [ ] Safety checks (secret scan, diff size limits)

### Secrets + Redaction (spec 60)
- [ ] `Redactor` module with regex patterns
- [ ] Apply to: logging, PubSub, artifacts, prompts, UI
- [ ] Migrate webhook_secret out of DB

---

## Suggested Closure Sequence

| # | Work Item | Depends On | Notes |
|---|-----------|:---:|---|
| 1 | Decide auth direction | — | Align code to spec (BasicAuth) or update spec. Blocks onboarding. |
| 2 | Decide secrets strategy | — | Env-var-only per spec, or AshCloak encryption. Blocks GitHub + redaction. |
| 3 | Decide Folio fate | — | Keep as demo? Evolve into Projects? Build Projects separately? |
| 4 | Fix branding + naming | — | Homepage text, health endpoint, .env.example |
| 5 | Build SystemConfig + setup gating | #1 | Singleton resource + redirect to `/setup` |
| 6 | Build onboarding wizard | #5 | LiveView wizard; can start with env var detection |
| 7 | Add Orchestration domain skeleton | — | WorkflowDefinition, WorkflowRun, Artifact, PullRequest as Ash resources |
| 8 | Wire manual run → Forge | #7 | WorkflowRun creates a Forge session → streams output |
| 9 | Add secrets redaction | #2 | Centralized Redactor on Forge output + artifacts |
| 10 | Implement git + PR automation | #8 | Shell git steps + GitHub API PR creation |
| 11 | Build "Implement Task" workflow | #8, #10 | First builtin: plan → implement → test → approve → ship |
| 12 | Expand test coverage | — | LiveView tests, Ash resource tests, integration tests |

---

## Appendix: Strong Building Blocks

These existing subsystems are ready to build on:

1. **Forge** — session lifecycle, PubSub streaming, and persistence provide the execution substrate for workflow runs
2. **GitHub Issue Bot** — demonstrates the full agent coordination pattern; can be wired into Forge sessions and support agent configs
3. **Mishka Chelekom components** — ~90 components ready for new pages (wizard, project list, run detail)
4. **Ash Framework foundation** — adding new domains/resources follows established patterns
5. **Sprites SDK integration** — sandbox execution works; needs connection to project/workspace abstractions
6. **Jido runtime** — `JidoCode.Jido` instance is running in the supervision tree, ready for agents
