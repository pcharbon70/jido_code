# Current Status & Gap Analysis

> Snapshot date: 2026-02-11

This document compares the **Jido Code vision and specs** against the **current repository state**. It is intended to be honest and actionable: what's real today, what's partially there, and what's not started.

---

## TL;DR

The app **runs** (Phoenix 1.8 + Ash) and has meaningful, functional subsystems:

- **Forge** sandbox sessions + streaming UI is the strongest foundation
- **GitHub Issue Bot** multi-agent orchestration exists with tests — a real showcase of Jido patterns
- **GitHub webhooks → signals** pipeline works via a Jido sensor

The MVP **product loop** — onboarding → import repo → pick workflow → run → approve → commit + PR — is **not implemented yet**. Several areas also conflict with the specs (auth model, secrets handling, naming conventions).

---

## MVP Requirements Scorecard

### Legend
- ✅ Built and functional
- 🟡 Partially built or prototyped
- ❌ Not started

| # | Spec MVP Feature | Status | Evidence / Notes |
|---|---|:---:|---|
| 1 | First-run onboarding wizard | ❌ | No `/setup` route. No `SystemConfig` resource. No first-run redirect logic. |
| 2 | Single-user, optional admin password | ❌ | Code uses AshAuthentication with registration + password reset + magic link. Spec calls for simple `Plug.BasicAuth` via env var. |
| 3 | GitHub App integration (user-provided) | 🟡 | GitHub domain exists with Repo/WebhookDelivery resources. No GitHub App JWT/installation token flow. No App setup wizard. |
| 4 | Project import (list repos → select → clone) | ❌ | No import flow. No cloning pipeline. No workspace management. |
| 5 | Local environment support | 🟡 | Forge can execute commands. Local workspace/project abstraction per spec not implemented. |
| 6 | Sprite sandbox support | 🟡 | Forge has Live Sprites client + session management. Not integrated with Projects/environments model. |
| 7 | Claude Code runner | ✅ | Forge `ClaudeCode` runner works. UI to create and stream sessions exists. |
| 8 | Manual workflow trigger from UI | 🟡 | Can manually create Forge sessions. "Workflow runs" (Runic-based) not present. |
| 9 | 2 builtin workflows (Implement Task, Fix Tests) | ❌ | Only spec docs exist. No Runic integration. No workflow definitions/runs. |
| 10 | Human approval gate | ❌ | No orchestration-level `awaiting_approval` state. Forge has `needs_input` but that's runner-level. |
| 11 | Auto commit + branch + PR | ❌ | No git operations flow. No PR creation pipeline. |
| 12 | Secrets management + redaction | ❌ | No redactor module. `GitHub.Repo.webhook_secret` stored in DB (conflicts with env-var-only spec). |
| 13 | Dashboard | 🟡 | `DashboardLive` exists but is a 20-line stub. |
| 14 | Test coverage | ❌ | 11 test files, mostly GitHub Issue Bot. Zero LiveView tests. Zero Ash resource tests. |

**Score: 1 ✅ / 6 🟡 / 7 ❌**

---

## What Exists Today (by Subsystem)

### 1. Phoenix + Ash App Foundation ✅

- Phoenix 1.8 + LiveView + Tailwind v4
- 4 Ash domains configured: `Accounts`, `GitHub`, `Forge.Domain`, `Folio`
- 15 Ash resources across domains
- 5 Ecto migrations
- JSON:API router (`/api/json/...`) with Swagger UI
- Dev tooling: Credo, Dialyxir, Doctor, Coveralls, git hooks
- Health endpoint: `GET /status` (spec says `/healthz` — naming mismatch)

### 2. Authentication 🟡 (misaligned with spec)

**What's built:**
- AshAuthentication with password + magic link strategies
- Sign-in, register, reset, confirm routes
- `User`, `Token`, `ApiKey` resources
- Authenticated LiveView sessions for app pages

**Gap vs spec:**
- Spec requires single-user, optional admin password via `JIDO_CODE_ADMIN_PASSWORD` env var
- Current code has full user registration, which the spec explicitly avoids
- Homepage still shows "Agent Jido" branding with register link
- This mismatch impacts onboarding, security model, and time-to-first-run

### 3. Forge — Sandbox Execution ✅ (strongest area)

**What's built:**
- Session lifecycle management + Ash persistence
- PubSub streaming output → LiveView UI
- 4 runners: `Shell`, `ClaudeCode`, `Workflow`, `Custom`
- Sprite client abstraction (Fake for dev, Live for real sandboxes)
- 3 LiveViews: Index (`/forge`), New (`/forge/new`), Show (`/forge/:session_id`)
- Streaming worker for real-time output

**What it enables today:**
- Create a Forge session from the UI
- Select a runner and execute commands
- View streaming output in real-time

**Gap vs spec:**
- Not connected to product-level concepts (Projects, Workspaces, Workflows)
- No secrets redaction on output streams
- No artifact collection from sessions
- No git operations post-session

### 4. GitHub Domain 🟡

**What's built:**
- `GitHub.Repo` resource (owner, name, settings, webhook_secret)
- `WebhookDelivery` persistence
- `IssueAnalysis` persistence
- `WebhookSensor`: polls pending deliveries → emits Jido signals (`github.issues.opened`, etc.)

**Gap vs spec:**
- No GitHub App auth flow (JWT → installation token caching)
- No webhook HTTP endpoint in web layer (spec: `POST /api/github/webhooks`)
- `webhook_secret` stored in DB — spec says secrets stay in env vars only
- No repo import/clone pipeline

### 5. GitHub Issue Bot ✅ (strong orchestration example)

**What's built (24 files):**
- `CoordinatorAgent` — orchestrates the full issue lifecycle
- `TriageAgent` — classifies and prioritizes issues
- `ResearchCoordinator` — fan-out to 4 parallel research workers
- `PullRequestCoordinator` — patch generation, quality check, submission
- CLI runner for debugging
- Most of the repo's test coverage lives here

**How it fits the vision:**
- Best current showcase of Jido agents, signals, fan-out workers, and directives
- Not yet wired into web UI or the workflow run model
- Could map into a "Support Agent Config" or builtin workflow in future

### 6. Folio Domain 🟡

**What's built:**
- `Project`, `InboxItem`, `Action` Ash resources
- `FolioLive` — 655-line LiveView (substantial prototyping)

**Gap vs spec:**
- Spec "Projects" domain focuses on GitHub repos + environments + workspaces
- Folio appears to be an older/different project management concept
- Needs alignment: either map into the spec's Project model or deprecate

### 7. UI Components & Design System ✅

**What's built:**
- ~70 Mishka Chelekom components (accordion, alert, avatar, badge, banner, button, card, carousel, chat, combobox, drawer, dropdown, modal, navbar, pagination, sidebar, stepper, tabs, timeline, toast, tooltip, etc.)
- Tailwind v4 setup with custom CSS
- Core components (`core_components.ex`)
- Layouts with sidebar navigation

**Gap vs spec:**
- MVP pages don't exist yet (setup wizard, projects list/detail, workflow library, run detail with timeline)
- Components are available but unclear how many are actually used in current views

### 8. LiveViews & Routes

**Current LiveViews (8):**

| LiveView | Route | Status |
|----------|-------|--------|
| `HomeLive` | `/` | Public landing page |
| `DashboardLive` | `/dashboard` | 20-line stub |
| `SettingsLive` | `/settings/:tab` | Functional (309 lines) |
| `FolioLive` | `/folio` | Prototyped (655 lines) |
| `Forge.IndexLive` | `/forge` | Functional (272 lines) |
| `Forge.NewLive` | `/forge/new` | Functional (168 lines) |
| `Forge.ShowLive` | `/forge/:session_id` | Functional (437 lines) |
| `Demos.ChatLive` | `/demos/chat` | Demo (684 lines) |

**Missing from specs:**
- `/setup` — Onboarding wizard (7 steps)
- `/projects` — Projects list
- `/projects/:id` — Project detail with runs
- `/projects/:id/runs/:run_id` — Run detail with timeline, output, approval gates
- `/workflows` — Workflow definitions library
- `/agents` — Support agent configs

### 9. Supervision Tree

```
JidoCode.Application
├── Telemetry
├── Repo (PostgreSQL)
├── DNSCluster
├── PubSub
├── Jido (agent runtime)
├── Endpoint
├── AshAuthentication.Supervisor
├── Registry (SessionRegistry)
├── DynamicSupervisor (SpriteSupervisor)
├── DynamicSupervisor (ExecSessionSupervisor)
├── Forge.Manager
└── [dev] Forge.SpriteClient.Fake
```

---

## Critical Alignment Issues

These are places where **current code actively conflicts with specs** (not just "not built yet").

### A. Auth Model Mismatch ⚠️ HIGH

| | Spec | Code |
|---|---|---|
| Strategy | Optional BasicAuth via env var | AshAuthentication (password + magic link + registration) |
| Users | Single user, no registration | Multi-user with `/register` |
| Impact | Onboarding, security model, UX complexity |

**Decision needed:** Simplify to spec's model, or update specs to accept AshAuthentication.

### B. Secrets Strategy Mismatch ⚠️ HIGH

| | Spec | Code |
|---|---|---|
| Storage | Env vars only; DB stores metadata | `GitHub.Repo.webhook_secret` persisted in Postgres |
| Redaction | Centralized Redactor module | No redaction anywhere |
| Impact | Security posture, OSS trust |

### C. Naming & Branding Drift ⚠️ MEDIUM

- Homepage renders "Agent Jido" — should be "Jido Code"
- Health endpoint is `/status` — spec says `/healthz`
- Sprites token env var is `SPRITES_TOKEN` — spec says `SPRITES_API_TOKEN`
- Some internal references may still use `AgentJido` namespace

### D. Folio vs Projects Domain ⚠️ MEDIUM

- Spec defines a `Projects` domain with GitHub-repo-centric model
- Code has a `Folio` domain with different semantics (InboxItem, Action)
- These need to be reconciled

---

## What's Not Started (by Spec Area)

### Onboarding Subsystem (specs 11, 20)
- [ ] `SystemConfig` resource (singleton, tracks setup completion)
- [ ] `Credential` resource (env var metadata, no secret values)
- [ ] `GithubAppInstallation` resource
- [ ] `/setup` LiveView wizard (7 steps)
- [ ] First-run detection + redirect middleware

### Orchestration Subsystem (specs 30, 31, 32)
- [ ] `WorkflowDefinition` resource
- [ ] `WorkflowRun` resource (with status lifecycle)
- [ ] `Artifact` resource (9 types)
- [ ] `PullRequest` resource
- [ ] Runic DAG integration
- [ ] Builtin workflow registration at startup
- [ ] "Implement Task" workflow template
- [ ] "Fix Failing Tests" workflow template
- [ ] Approval gate UI + state machine

### Project Import & Workspaces (specs 40, 50)
- [ ] Repo list/import flow (GitHub API)
- [ ] Clone pipeline (git clone → workspace setup)
- [ ] Workspace behaviour (9 callbacks)
- [ ] Local workspace implementation
- [ ] Sprite workspace implementation
- [ ] Per-run setup (sync, clean, branch, secrets, bootstrap)

### Git & PR Automation (spec 51)
- [ ] Branch creation (`jido-code/<workflow>/<short-id>`)
- [ ] Commit with conventional message format
- [ ] Push to remote
- [ ] PR creation via GitHub API
- [ ] PR body template with metadata
- [ ] 10 safety checks (secret scan, diff size, force push protection)
- [ ] Dry-run mode

### Secrets & Redaction (spec 60)
- [ ] `Redactor` module with regex patterns
- [ ] Apply to: logging, PubSub streams, artifacts, prompts, UI
- [ ] Migrate existing DB-stored secrets to env-var-only model

---

## Gap Closure Plan (Suggested Sequence)

Effort sizing: **S** = days, **M** = 1-2 weeks, **L** = 2-4 weeks

| # | Work Item | Size | Dependencies | Notes |
|---|-----------|:---:|---|---|
| 1 | **Decide auth direction** | S | — | Align code to spec (BasicAuth) or update spec to accept AshAuth. Blocks onboarding. |
| 2 | **Add SystemConfig + setup gating** | M | #1 | Singleton resource, first-run redirect to `/setup`. |
| 3 | **Build onboarding wizard** | M | #2 | 7-step LiveView. Can start with detection-only (read env vars, show status). |
| 4 | **Add Orchestration domain skeleton** | M | — | WorkflowDefinition, WorkflowRun, Artifact, PullRequest resources. No execution yet. |
| 5 | **Build workflow run UI** | M | #4 | Run detail page with timeline, output stream (reuse Forge streaming). |
| 6 | **Wire manual run → Forge** | M | #4, #5 | Create WorkflowRun → start Forge session → stream output → collect artifacts. |
| 7 | **Add secrets redaction** | M | — | Centralized Redactor. Apply to Forge output streaming + artifacts. Fix DB secret storage. |
| 8 | **Implement git + PR automation** | L | #6 | Shell git steps (branch, commit, push). GitHub API PR creation. Safety checks. |
| 9 | **Build "Implement Task" workflow** | M | #6, #8 | First builtin: plan → implement → test → approve → commit + PR. |
| 10 | **Build "Fix Failing Tests" workflow** | M | #9 | Second builtin: reproduce → diagnose → fix → verify → approve → commit + PR. |
| 11 | **Align naming + branding** | S | — | Homepage, health endpoint, env var names, any remaining `AgentJido` references. |
| 12 | **Test coverage push** | M | #1-#10 | LiveView tests, Ash resource tests, workflow integration tests. |

---

## Appendix: Current Route Map

```
Public
  GET  /                    → HomeLive
  *    /auth/*               → AuthController (AshAuthentication)
  GET  /sign-in              → AuthController
  GET  /register             → AuthController
  GET  /reset                → AuthController

Authenticated (AshAuthentication session)
  GET  /dashboard            → DashboardLive (stub)
  GET  /settings/:tab?       → SettingsLive
  GET  /forge                → Forge.IndexLive
  GET  /forge/new            → Forge.NewLive
  GET  /forge/:session_id    → Forge.ShowLive
  GET  /folio                → FolioLive
  GET  /demos/chat           → Demos.ChatLive

API
  *    /api/json/*            → AshJsonApi + SwaggerUI
  POST /rpc/run              → AshTypescriptRpcController
  POST /rpc/validate         → AshTypescriptRpcController

Infrastructure
  GET  /status               → HeartbeatPlug

Dev-only
  GET  /dev/dashboard        → Phoenix.LiveDashboard
  GET  /dev/mailbox           → Swoosh mailbox
  GET  /admin                → AshAdmin
```

---

## Appendix: Strong Building Blocks (Reusable)

These existing subsystems provide a solid foundation for MVP completion:

1. **Forge session lifecycle + PubSub streaming** → reusable for workflow run output, artifact collection, and future durable execution
2. **GitHub Issue Bot agents** → showcase of Jido patterns (signals, directives, fan-out). Maps to future "support agent configs" or builtin workflows
3. **Mishka Chelekom UI components** → ready for new pages (wizard, project list, run detail, workflow library)
4. **Ash Framework foundation** → adding new resources/domains follows established patterns
5. **Sprites SDK integration** → sandbox execution already works; needs wiring to project/workspace model
