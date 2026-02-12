# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Jido Code is an Elixir/Phoenix + LiveView application that serves as an AI coding orchestrator built on the Jido agent runtime framework. It orchestrates multiple AI coding agents (primarily Claude Code) in isolated sandbox environments with durable workflows, real-time observability, and human approval gates.

**Status: Alpha / Developer-focused** — Many planned features exist as stubs. Two main working showcases:
- **Forge** — production-quality OTP sandbox execution engine
- **GitHub Issue Bot** — multi-agent Jido coordination showcase

## Code Conventions

**IMPORTANT**: This project uses `usage_rules` to sync LLM-friendly guidelines from dependencies. See [`AGENTS.md`](AGENTS.md) for comprehensive Elixir, Phoenix, LiveView, Ash, and Jido conventions.

Key points from AGENTS.md:
- Use `mix precommit` when done with changes
- Use `:req` for HTTP requests (not httpoison/tesla/httpc)
- Follow Phoenix v1.8 patterns (Layouts.app, current_scope for auth, core_components)
- Use LiveView streams for collections (not lists)
- Use `start_supervised!/1` in tests, avoid `Process.sleep/1`

## Development Commands

```bash
mix setup              # Install deps, setup Ash, build assets, run seeds
mix phx.server         # Start Phoenix server (localhost:4000)
mix test               # Run tests
mix quality            # Compile warnings + format + credo + doctor
mix precommit          # Compile + format + test (CI alias)
mix assets.build       # Build CSS/JS assets
mix ash.setup          # Setup Ash resources
mix sync_rules         # Sync AGENTS.md from dependency usage rules
```

## Architecture

### Core Stack
- **Backend**: Elixir 1.18+ with Phoenix 1.8 (LiveView 1.1)
- **Data Layer**: Ash framework (Postgres) with AshAuthentication
- **Agent Runtime**: Jido framework (`jido`, `jido_action`, `jido_signal`, `jido_ai`)
- **Frontend**: React 19 + Tailwind CSS v4 (~90 Mishka Chelekom components)
- **Sandboxing**: Sprites SDK for cloud containers + Fake client for local dev

### Forge: Sandbox Execution Engine

The most production-complete subsystem. Key modules:

- `JidoCode.Forge` — Public API facade
- `Forge.Manager` — Lifecycle GenServer with DynamicSupervisor + Registry, concurrency control
- `Forge.SpriteSession` — Per-session GenServer: provision → bootstrap → init → iterate → input → cleanup
- `Forge.Runner` — Behaviour with iteration statuses: `:continue`, `:done`, `:needs_input`, `:blocked`, `:error`

Built-in runners: `Shell`, `ClaudeCode`, `Workflow`, `Custom`

Sprite clients: `Fake` (local tmp dir + System.cmd) for dev/test, `Live` (real Sprites SDK)

### GitHub Issue Bot: Multi-Agent Showcase

Demonstrates Jido coordination patterns:

```
CoordinatorAgent
├── TriageAgent + TriageAction
├── ResearchCoordinator
│   ├── CodeSearchAgent + CodeSearchAction
│   ├── PRSearchAgent + PRSearchAction
│   ├── ReproductionAgent + ReproductionAction
│   └── RootCauseAgent + RootCauseAction
└── PullRequestCoordinator
    ├── PatchAgent + PatchAction
    ├── QualityAgent + QualityAction
    └── PRSubmitAgent + PRSubmitAction
```

### OTP Structure

```
JidoCode.Application
├── JidoCodeWeb.Telemetry
├── JidoCode.Repo (Postgres)
├── DNSCluster
├── Phoenix.PubSub
├── JidoCode.Jido (Agent runtime)
├── JidoCodeWeb.Endpoint
├── AshAuthentication.Supervisor
├── Forge.SessionRegistry (Registry)
├── Forge.SpriteSupervisor (DynamicSupervisor)
├── Forge.ExecSessionSupervisor (DynamicSupervisor)
└── Forge.Manager (GenServer)
```

### PubSub Topics

- `forge:sessions` — Global session events
- `forge:session:<id>` — Per-session updates for streaming UI

## Key Design Patterns

1. **Pluggable Architecture**: Runners and SpriteClients are swappable behaviours
2. **Iteration-Based Model**: Work in discrete iterations with pause/resume support
3. **Separation of Runtime vs Persistence**: GenServer state is authoritative; Ash DB is for audit
4. **Real-Time via PubSub**: Subscribe to topics for live UI updates
5. **Concurrency Control**: Global limits (50 total) prevent resource exhaustion

## Concurrency Limits (enforced by Manager)

- Max total sessions: 50
- Max `claude_code` runners: 10
- Max `shell` runners: 20
- Max `workflow` runners: 10

## Important Constraints

- **Secrets**: `webhook_secret` currently stored in DB (should be env-only). Use `.env` for local dev.
- **Required env vars** not in `.env.example`: `ANTHROPIC_API_KEY`, `SPRITES_API_TOKEN`, GitHub App credentials
- **Authentication**: AshAuthentication with password, magic link, API key
- **Known gaps**: No onboarding wizard, GitHub Issue Bot not wired end-to-end

## Additional Documentation

- `AGENTS.md` — Comprehensive Elixir/Phoenix/Ash/Jido conventions (synced from deps)
- `FORGE_OVERVIEW.md` — Forge architecture deep dive
- `specs/` — Product specs and PRD
- `specs/current_status.md` — Detailed gap analysis
