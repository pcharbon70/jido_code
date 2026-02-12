# Jido Code

[![CI](https://github.com/agentjido/jido_code/actions/workflows/ci.yml/badge.svg)](https://github.com/agentjido/jido_code/actions/workflows/ci.yml)

**Jido Code** is an open-source, self-hosted coding orchestrator that turns AI coding agents into **managed, observable, composable development workflows**.

Instead of chatting with a single AI tool in a terminal, Jido Code lets you define **durable, multi-step workflows** that orchestrate multiple agents — Claude Code, Ampcode, custom tools — running in isolated environments, with human approval gates, automatic git operations, and pull request creation.

> **Status: Alpha / Early Development**
>
> The Phoenix app compiles and runs, and several subsystems are functional:
> - **Forge** (sandbox sessions, runners, streaming UI) is the most complete area
> - A **GitHub Issue Bot** (multi-agent triage, research, PR coordination) demonstrates Jido orchestration patterns
>
> Key MVP product features (onboarding wizard, workflow definitions/runs, git/PR automation) are not yet implemented.
> See [`specs/current_status.md`](specs/current_status.md) for the full gap analysis.

---

## Why Jido Code

| Chat-based tools | Jido Code |
|------------------|-----------|
| Single session, ephemeral | Durable workflows with checkpoints |
| One agent at a time | Multi-agent orchestration with handoffs |
| Manual git operations | Automated commit + PR |
| No observability | Full execution timeline + cost tracking |
| No composition | Workflow pipelines (Runic DAGs) |
| No issue management | Built-in GitHub Issue Bot agents |

Jido Code is also the **flagship showcase** for the [Jido framework ecosystem](https://github.com/agentjido) — demonstrating how agents, actions, signals, and durable workflows compose into a real product.

---

## What's in the Repo Today

### Forge — Sandbox Execution Engine ✅
- Session lifecycle management with PubSub streaming
- Multiple runners: **Shell**, **Claude Code**, **Workflow**, **Custom**
- Sprite clients (Fake for dev, Live for [Fly Sprites](https://fly.io) sandboxes)
- Full LiveView UI: session index, creation, and real-time output streaming

### GitHub Issue Bot — Multi-Agent Orchestration ✅
- CoordinatorAgent → TriageAgent → ResearchCoordinator (parallel workers) → PullRequestCoordinator
- Demonstrates Jido signals, directives, and fan-out patterns
- CLI runner for debugging

### GitHub Domain 🟡
- Ash resources for repos, webhook deliveries, and issue analyses
- WebhookSensor that converts deliveries into Jido signals

### Web App Foundation ✅
- Phoenix 1.8 + LiveView + Tailwind v4
- Ash Framework domains (Accounts, GitHub, Forge, Folio)
- AshAuthentication (password + magic link)
- ~70 UI components (Mishka Chelekom)
- JSON:API endpoints + Swagger UI
- Dev tools: AshAdmin, LiveDashboard

---

## Roadmap

### Phase 1: MVP (v0.1) — *in progress*
- Onboarding wizard (API keys, GitHub App, environment)
- Import GitHub repos
- Local environment support
- 2 builtin workflows: "Implement Task" and "Fix Failing Tests"
- Claude Code runner
- Manual workflow trigger from UI
- Commit + PR on completion
- Basic admin password auth

### Phase 2: Orchestration (v0.2)
- Sprite (cloud sandbox) environment support
- Custom workflow authoring (code-first, Runic DAG)
- Ampcode runner
- Research → Design → Implement pipeline
- GitHub Issue Bot integration
- Webhook-triggered workflows
- Execution cost tracking and budgets

### Phase 3: Polish (v0.3)
- Visual workflow builder UI
- Workflow templates library
- Scheduled workflows (cron-style)
- Multi-repo workflows
- Enhanced diff viewer and artifact browser

Full specs live in [`/specs`](specs/).

---

## Getting Started

### Prerequisites

- Elixir 1.18+
- PostgreSQL 14+
- Node.js (for assets)
- Optional: `claude` CLI (for Claude Code runner)

### Setup

```bash
git clone https://github.com/agentjido/jido_code.git
cd jido_code

# Install dependencies and setup database
mix setup

# Start the Phoenix server
mix phx.server
```

Visit [localhost:4000](http://localhost:4000).

### Environment Variables

Copy `.env.example` and configure:

```bash
cp .env.example .env
```

Key variables:
- `ANTHROPIC_API_KEY` — for Claude Code runner
- `GITHUB_APP_*` — for GitHub App integration
- `SPRITES_API_TOKEN` — for Fly Sprites sandbox execution

---

## Development

```bash
# Run tests
mix test

# Run all quality checks (compile warnings, format, credo, doctor)
mix quality

# Pre-commit checks (compile, format, test)
mix precommit

# Test coverage report
mix coveralls.html
```

### Project Structure

```
lib/
├── jido_code/                # Core business logic
│   ├── accounts/             # User auth (Ash resources)
│   ├── forge/                # Sandbox execution engine
│   │   ├── runners/          # Shell, ClaudeCode, Workflow, Custom
│   │   └── sprite_client/    # Fake + Live Sprites clients
│   ├── folio/                # Projects domain
│   ├── github/               # GitHub integration (repos, webhooks)
│   └── github_issue_bot/     # Multi-agent issue bot
│       ├── agents/           # Coordinator, Triage, Research, PR
│       └── actions/          # Composable bot actions
├── jido_code_web/            # Web layer
│   ├── components/           # UI component library
│   ├── controllers/          # HTTP controllers
│   └── live/                 # LiveView modules
│       ├── forge/            # Session management UI
│       └── demos/            # Demo LiveViews
specs/                        # Design documents & PRD
```

---

## Jido Ecosystem

Jido Code builds on:

| Package | Role |
|---------|------|
| [`jido`](https://github.com/agentjido/jido) | Core agent runtime, strategies, signals |
| [`jido_action`](https://github.com/agentjido/jido_action) | Composable action definitions |
| [`jido_signal`](https://github.com/agentjido/jido_signal) | Agent communication envelopes |
| [`jido_ai`](https://github.com/agentjido/jido_ai) | LLM integration (Anthropic, OpenAI) |
| [`req_llm`](https://github.com/agentjido/req_llm) | HTTP LLM client |
| [`ash`](https://ash-hq.org) | Data modeling, persistence |
| [`ash_authentication`](https://github.com/team-alembic/ash_authentication) | Auth framework |

---

## Documentation

- [Specs & PRD](specs/README.md) — Full design documents
- [Current Status & Gaps](specs/current_status.md) — What's built vs what's planned
- [Contributing](CONTRIBUTING.md) — Contribution guidelines
- [Changelog](CHANGELOG.md) — Version history

---

## License

Apache-2.0 — see [LICENSE](LICENSE) for details.
