# 02 — Requirements & Scope

## Hard Requirements

### R1: Single-User, Optional Auth
- The application serves a single user
- An optional admin password can be configured via env var (`JIDO_CODE_ADMIN_PASSWORD`)
- No user registration, no RBAC, no multi-tenancy

### R2: Onboarding Flow
- First-run detection triggers a setup wizard
- Steps: persistence setup, LLM API keys (from env vars), GitHub App connection, environment choice
- Each step validates before proceeding (test API key, verify GitHub App install)
- Settings are persisted and editable later via Settings page

### R3: GitHub App Integration
- Users create their own GitHub App (no private keys in open source)
- GitHub App credentials provided via env vars
- The platform can list, clone, and manage repositories
- Webhooks are received for issue/PR events

### R4: Project Cloning & Environments
- Projects are cloned to either a local folder or a Sprite cloud sandbox
- Environment choice is per-project, configurable
- Both environments expose a uniform interface for git, filesystem, and command execution

### R5: Customized Workflows (Runic)
- Users can configure and run durable, multi-step workflows
- Workflows are defined as Runic DAGs (code-first for MVP)
- Builtin workflow templates are provided
- Workflows support human-in-the-loop approval gates (configurable per workflow)
- Workflows support agent handoffs with different models per phase

### R6: AI Coding Agent Orchestration
- Workflows orchestrate Jido agents that wrap coding CLIs
- MVP: Claude Code runner
- Future: Ampcode runner, custom runners
- Agents run inside Forge sessions (local or sprite)
- Multi-model routing: cheap models for volume, expensive models for judgment

### R7: Commit & PR on Completion
- Upon workflow completion, the system can:
  - Create a branch with a conventional name
  - Commit changes with a descriptive message
  - Push and open a pull request on GitHub
- Approval gates are configurable per workflow

### R8: Support Agents
- A library of "support agents" can be enabled per-project
- MVP: GitHub Issue Bot (triage, research, respond)
- Support agents are triggered by GitHub webhooks
- Each support agent is independently configurable

### R9: Real-Time Observability
- Workflow runs stream output to the LiveView UI in real-time
- Execution timeline shows each step, its status, duration, and output
- PubSub-based updates (existing Forge infrastructure)

### R10: Open Source Showcase
- The codebase demonstrates idiomatic use of the Jido ecosystem
- Clear separation of concerns: agents, actions, workflows, execution, persistence
- Well-documented, well-tested, contributor-friendly
- No secrets or private keys in the source code

### R11: Dual-Mode Deployment
- Runs as a cloud service on Fly Machine (primary)
- Runs as a local Phoenix app on developer's machine
- Configuration via environment variables in both modes

---

## MVP Scope (Phase 1)

### In Scope
- [ ] First-run onboarding wizard
- [ ] LLM API key detection from env vars (Anthropic primary)
- [ ] GitHub App connection (user-created App, credentials via env vars)
- [ ] Project import from GitHub (list repos, select, clone)
- [ ] Local environment support (clone to host filesystem)
- [ ] Claude Code runner (via Forge)
- [ ] 2 builtin workflows: "Implement Task" and "Fix Failing Tests"
- [ ] Manual workflow trigger from UI
- [ ] Real-time output streaming in UI
- [ ] Human approval gate (configurable per workflow)
- [ ] Auto-commit + branch + PR creation
- [ ] Basic admin password (optional, env var)
- [ ] Settings page for managing connections
- [ ] PostgreSQL persistence (Ash)
- [ ] Fly Machine deployment support

### Out of Scope (Phase 1)
- Visual workflow builder UI
- Sprite/cloud sandbox support (Phase 2)
- Ampcode runner (Phase 2)
- Research → Design → Implement pipeline (Phase 2)
- GitHub Issue Bot integration (Phase 2)
- Webhook-triggered workflows (Phase 2)
- Scheduled/cron workflows (Phase 3)
- Multi-repo workflows (Phase 3)
- Execution cost tracking and budgets (Phase 2)
- Workflow templates marketplace (Phase 3)
- Multi-user / RBAC / organizations
- Mobile or responsive design beyond desktop
- API access (JSON:API exists via Ash but not a priority)

---

## Non-Goals

These are explicitly out of scope for the foreseeable future:

1. **Multi-tenancy** — Jido Code is single-user by design
2. **Hosted SaaS** — it is self-hosted only (Fly or local)
3. **IDE integration** — it is a standalone web app, not an extension
4. **Code editor** — it orchestrates coding agents, it doesn't replace your editor
5. **General-purpose agent platform** — it is focused on coding workflows specifically
6. **LLM fine-tuning or training** — it uses LLMs via API, it doesn't train them
7. **Secrets in source** — all credentials come from environment variables

---

## Technical Constraints

| Constraint | Detail |
|------------|--------|
| Runtime | Elixir/OTP, Phoenix 1.8 |
| Database | PostgreSQL 14+ |
| UI | Phoenix LiveView (server-rendered, real-time) |
| Data modeling | Ash Framework |
| Auth | Optional basic auth via env var |
| CSS | Tailwind CSS v4 |
| LLM client | Req + req_llm |
| Agent runtime | Jido |
| Workflows | jido_runic (Runic DAGs) |
| Execution | Forge (existing subsystem) |
| Sandbox | Sprites SDK (Phase 2) |
| Secrets | Environment variables (no Cloak for MVP) |
| Deployment | Fly Machine or local Phoenix app |
