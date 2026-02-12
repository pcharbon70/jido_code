# 00 — Vision & PRD

## Vision

Jido Code is an open-source, self-hosted coding orchestrator that turns AI coding agents into a managed, observable, and composable development workflow.

Instead of chatting with a single AI coding tool in a terminal, Jido Code lets you define **durable, multi-step workflows** that orchestrate multiple agents — Claude Code, Ampcode, custom tools — running in isolated environments, with human approval gates, automatic git operations, and pull request creation.

It is the flagship showcase for the **Jido framework ecosystem**: demonstrating how Jido's agents, actions, signals, durable workflows (Runic), and sandboxed execution (Forge/Sprites) compose into a real, useful product.

## Why Open Source

- **Showcase the Jido ecosystem** — developers learn Jido by seeing it in production
- **Transparency** — coding orchestrators touch your code; you should be able to audit them
- **Extensibility** — anyone can add new runners, agents, workflow templates, and integrations
- **Community** — OSS maintainers are the target users; they should own their tools
- **No private keys in source** — users bring their own GitHub App and API keys

## Target Users

### Primary: Solo Developer / Small Team Lead
- Manages 1-10 repositories
- Uses AI coding tools daily (Claude Code, Cursor, Copilot, Amp)
- Wants to automate repetitive coding workflows (fix CI, implement issues, refactor)
- Comfortable self-hosting a Phoenix app (on Fly or locally)

### Secondary: OSS Maintainer
- Manages popular open-source projects
- Drowning in issues, PRs, and triage work
- Wants automated issue triage, research, and response
- Needs guardrails: nothing ships without approval

## Primary Jobs-to-be-Done

1. **"Run this coding task across my repo"** — define a workflow, point it at a repo, get a PR
2. **"Automate my issue triage"** — configure a bot that classifies, researches, and responds to GitHub issues
3. **"Compose multi-step coding pipelines"** — chain agents: research → design → implement → test → review → PR
4. **"See what my agents are doing"** — real-time streaming output, execution timeline, cost tracking

## Core Principles

| Principle | Meaning |
|-----------|---------|
| **Durable by default** | Workflows survive restarts. Every step is checkpointed. Runic provides provenance. |
| **Observable** | Every agent action, signal, and output is streamed to the UI and persisted. |
| **Reproducible** | Environments are defined as specs. A workflow run on Sprites behaves the same as local. |
| **Composable** | Agents, actions, and workflows are building blocks. Users compose their own pipelines. |
| **Safe** | Nothing ships without an approval gate (configurable per workflow). Secrets never leak to LLMs. |
| **Single-user simple** | No RBAC, no orgs, no multi-tenancy overhead. One person, one instance. |

## Key Differentiators vs Chat-Based Coding Tools

| Chat-based tools | Jido Code |
|------------------|-----------|
| Single session, ephemeral | Durable workflows with checkpoints |
| One agent at a time | Multi-agent orchestration with handoffs |
| Manual git operations | Automated commit + PR |
| No observability | Full execution timeline + cost tracking |
| No composition | Zapier-style workflow builder (Runic DAGs) |
| No issue management | Built-in GitHub Issue Bot agents |
| Same model for everything | Model routing: cheap for volume, expensive for judgment |

## Success Metrics

| Metric | Target |
|--------|--------|
| Time from install to first workflow run | < 10 minutes |
| Time from workflow completion to PR | < 30 seconds |
| Workflow completion rate (no crashes) | > 95% |
| GitHub stars (vanity but matters for showcase) | 500 in 6 months |

## Release Phases

### Phase 1: MVP (v0.1)
- Onboarding wizard (API keys, GitHub App, environment)
- Import GitHub repos
- Local environment support
- 2 builtin workflows: "Implement Task" and "Fix Failing Tests"
- Claude Code runner
- Manual workflow trigger from UI
- Commit + PR on completion
- Basic admin password auth
- Dual-mode deployment (Fly + local)

### Phase 2: Orchestration (v0.2)
- Sprite (cloud sandbox) environment support
- Custom workflow authoring (code-first, Runic DAG)
- Ampcode runner
- Research → Design → Implement pipeline (multi-phase workflow)
- GitHub Issue Bot (triage + research + respond)
- Webhook-triggered workflows (issue opened, PR comment)
- Execution cost tracking and budgets
- Multi-model routing (cheap for volume, expensive for judgment)

### Phase 3: Polish (v0.3)
- Visual workflow builder UI
- Workflow templates marketplace/library
- Scheduled workflows (cron-style)
- Multi-repo workflows
- Enhanced diff viewer and artifact browser
- LiveDashboard integration for observability

## Jido Ecosystem Dependencies

| Package | Role in Jido Code |
|---------|-------------------|
| `jido` | Core agent runtime, strategies, signals |
| `jido_action` | Composable action definitions |
| `jido_signal` | Agent communication envelopes |
| `jido_ai` | LLM integration (Anthropic, OpenAI) |
| `jido_runic` | Durable workflow DAGs |
| `jido_claude` | Claude Code CLI wrapper |
| `req_llm` | HTTP LLM client |
| `ash` | Data modeling, persistence, admin |
| `ash_authentication` | Auth (simplified for single-user) |
