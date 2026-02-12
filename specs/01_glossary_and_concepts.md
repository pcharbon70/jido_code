# 01 — Glossary & Concepts

## Core Concepts

### Agent
A **Jido Agent** is a stateful entity that receives signals, selects actions via a strategy, and emits results. In Jido Code, agents wrap coding tools (Claude Code, Ampcode) or perform support tasks (issue triage, code search).

An agent has:
- A **name** and **identity**
- A **strategy** that determines how it processes signals (e.g., `JidoRunic.Strategy` for workflow-driven agents)
- **State** that persists across signal processing cycles
- **Actions** it can perform

### Action
A **Jido Action** is a composable, validated unit of work. Actions are pure functions with declared schemas for inputs and outputs. They are the atomic building blocks of workflows.

Examples: `CloneRepo`, `RunTests`, `CommitChanges`, `CreatePR`, `TriageIssue`, `SearchCode`

### Signal
A **Jido Signal** is a typed message envelope used for agent communication. Signals carry:
- A **type** (e.g., `"workflow.step.completed"`, `"issue.opened"`)
- **Data** payload
- **Source** and **causation** metadata for provenance

### Workflow (Runic DAG)
A **Workflow** is a durable, directed acyclic graph (DAG) of actions, powered by `jido_runic`. Each node in the DAG is a `JidoRunic.ActionNode` that wraps a Jido Action.

Workflows are:
- **Durable** — state survives process restarts
- **Observable** — every step produces facts with provenance
- **Composable** — nodes can be added, removed, or rewired
- **Signal-gated** — branches can activate based on signal type patterns

Think of it as "Zapier for coding tasks, but the nodes are AI agents."

### Workflow Run
A **Workflow Run** is a single execution instance of a workflow definition. It tracks:
- Current step / phase
- Input parameters
- Produced artifacts
- Status (pending, running, awaiting_approval, completed, failed)
- Timing and cost data

### Runner
A **Runner** is a Forge execution adapter that defines what happens inside a sandbox per iteration. Runners implement the `AgentJido.Forge.Runner` behaviour.

Built-in runners:
| Runner | Purpose |
|--------|---------|
| `Shell` | Execute shell commands |
| `ClaudeCode` | Drive Claude Code CLI |
| `Workflow` | Multi-step data-driven workflows |
| `Custom` | User-supplied module/function |

Future: `Ampcode` runner.

### Forge Session
A **Forge Session** is an isolated execution runtime managed by the Forge subsystem. It:
1. Provisions an environment (local temp dir or sprite container)
2. Bootstraps the environment (install tools, inject secrets, clone repo)
3. Runs a runner in iteration loops
4. Streams output via PubSub
5. Cleans up on termination

### Sprite
A **Sprite** is a cloud sandbox container provisioned via the Sprites SDK. Sprites provide:
- Isolated filesystem
- Network access (configurable)
- Persistent or ephemeral storage
- API for exec, file I/O, and environment injection

### Project
A **Project** in Jido Code represents a GitHub repository that has been imported. It stores:
- GitHub repo metadata (owner, name, default branch)
- Environment configuration (local path or sprite spec)
- Workflow associations
- Support agent configurations

### Workspace
A **Workspace** is the execution environment for a project. Two types:
- **Local**: a directory on the host filesystem where the repo is cloned
- **Sprite**: a cloud sandbox container with the repo cloned inside

The workspace provides a uniform interface regardless of type: filesystem access, git operations, command execution, and secrets injection.

### Artifact
An **Artifact** is any output produced by a workflow run:
- Execution logs
- Diff/patch files
- Research reports (from Issue Bot)
- PR URLs
- Cost summaries
- Agent conversation transcripts

### Support Agent
A **Support Agent** is a long-lived agent configured per-project to perform ongoing tasks:
- **GitHub Issue Bot**: triages new issues, researches root causes, posts responses
- Future: PR review bot, dependency update bot, release bot

## Conceptual Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Jido Code (Phoenix App)                   │
├──────────────┬──────────────┬──────────────┬────────────────────┤
│   Web UI     │  Workflows   │   Forge      │   GitHub           │
│  (LiveView)  │  (Runic)     │ (Execution)  │  (App + Webhooks)  │
├──────────────┴──────────────┴──────────────┴────────────────────┤
│                    Ash Domain Model (PostgreSQL)                  │
├──────────────┬──────────────┬──────────────┬────────────────────┤
│   jido       │  jido_ai     │ jido_action  │  jido_signal       │
│  (agents)    │  (LLM)       │ (actions)    │  (messaging)       │
└──────────────┴──────────────┴──────────────┴────────────────────┘
```

## Relationship Map

```
Project  ──has-many──▶  WorkflowDefinition
Project  ──has-one───▶  Workspace (local or sprite config)
Project  ──has-many──▶  SupportAgent configs

WorkflowDefinition  ──instantiates──▶  WorkflowRun
WorkflowRun  ──creates──▶  ForgeSession(s)
WorkflowRun  ──produces──▶  Artifact(s)
WorkflowRun  ──may-create──▶  PullRequest

ForgeSession  ──uses──▶  Runner (ClaudeCode, Shell, etc.)
ForgeSession  ──runs-in──▶  Workspace (local dir or sprite)

SupportAgent  ──triggered-by──▶  GitHub Webhook
SupportAgent  ──creates──▶  WorkflowRun
```
