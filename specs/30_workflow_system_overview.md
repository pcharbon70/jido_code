# 30 — Workflow System Overview

## Overview

Jido Code's workflow system is built on `jido_runic` — a bridge between Runic's DAG-based workflow engine and Jido's signal-driven agent framework. Workflows define durable, multi-step coding pipelines that orchestrate AI agents.

Think of it as **"Zapier for coding tasks"**: each node in the workflow is an action (clone repo, run Claude Code, run tests, commit, open PR), and the DAG defines the execution order, branching, and data flow between them.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    WorkflowDefinition                         │
│                 (stored Runic DAG + metadata)                 │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ActionNode    ActionNode    ActionNode    ActionNode         │
│  (plan)    →   (implement) → (test)     → (commit+PR)       │
│                     ↓                                        │
│               ApprovalGate                                   │
│            (human-in-the-loop)                               │
│                                                              │
└──────────────────────────────────────────────────────────────┘
                         │
                    instantiate
                         ↓
┌──────────────────────────────────────────────────────────────┐
│                     WorkflowRun                               │
│              (runtime state + results)                        │
├──────────────────────────────────────────────────────────────┤
│  - current_step: :implement                                  │
│  - step_results: %{plan: %{...}}                             │
│  - status: :running                                          │
│  - forge_session_id: "sess-abc123"                           │
│  - artifacts: [%Artifact{type: :log}, ...]                   │
└──────────────────────────────────────────────────────────────┘
```

## Workflow Authoring (Code-First)

Workflows are defined in Elixir code using `jido_runic` APIs:

```elixir
defmodule JidoCode.Workflows.ImplementTask do
  alias Runic.Workflow
  alias JidoRunic.ActionNode

  def build(params) do
    plan = ActionNode.new(JidoCode.Actions.PlanTask, %{task: params.task}, name: :plan)
    implement = ActionNode.new(JidoCode.Actions.RunCodingAgent, %{}, name: :implement)
    test = ActionNode.new(JidoCode.Actions.RunTests, %{}, name: :test)
    approve = ActionNode.new(JidoCode.Actions.RequestApproval, %{}, name: :approve)
    ship = ActionNode.new(JidoCode.Actions.CommitAndPR, %{}, name: :ship)

    Workflow.new(:implement_task)
    |> Workflow.add(plan)
    |> Workflow.add(implement, to: :plan)
    |> Workflow.add(test, to: :implement)
    |> Workflow.add(approve, to: :test)
    |> Workflow.add(ship, to: :approve)
  end
end
```

Visual builder is deferred to a later phase. For now, workflows are code-first.

## Workflow Definition Storage

Workflow definitions are stored as Ash resources with a serialized DAG:

```elixir
%WorkflowDefinition{
  name: "implement_task",
  display_name: "Implement Task",
  description: "Plan, implement, test, and open a PR for a coding task",
  category: :builtin,
  definition: %{
    nodes: [...],
    edges: [...],
    metadata: %{}
  },
  input_schema: %{
    "task" => %{type: "string", required: true, description: "What to implement"},
    "branch_prefix" => %{type: "string", default: "jido-code/"}
  },
  approval_required: true  # per-workflow configurable
}
```

## Trigger Types

| Trigger | Description | MVP? |
|---------|-------------|------|
| **Manual** | User clicks "Run Workflow" in UI | Yes |
| **Webhook** | GitHub event (issue opened, PR comment, push) | Phase 2 |
| **Schedule** | Cron-style recurring execution | Phase 3 |
| **Support Agent** | Triggered by a support agent's analysis | Phase 2 |

## Execution Flow

### 1. Trigger
A workflow run is created with:
- Reference to the `WorkflowDefinition`
- Reference to the `Project`
- Runtime inputs (task description, branch name, etc.)
- Trigger metadata (who/what started it)

### 2. Initialize
- Create `WorkflowRun` resource (status: `:pending`)
- Resolve the Runic DAG from the definition
- Set up the `JidoRunic.Strategy` for the coordinating agent
- Provision the workspace (ensure repo is cloned and up-to-date)

### 3. Execute
- Transition to `:running`
- Feed initial input as a signal to the strategy
- The strategy produces `ExecuteRunnable` directives
- Each directive maps to a Forge session or direct action execution
- Results are applied back to the workflow, advancing the DAG
- PubSub events broadcast step transitions

### 4. Approval Gates
- When a workflow reaches an approval node, it transitions to `:awaiting_approval`
- The UI shows an approval prompt with context (diff preview, test results, cost so far)
- User approves → workflow continues
- User rejects → workflow transitions to `:cancelled`
- Timeout behavior: configurable (default: wait indefinitely)
- **Per-workflow**: each workflow definition controls whether approval is required

### 5. Complete
- When the DAG is satisfied, transition to `:completed`
- Collect all artifacts
- If the workflow includes a PR step, the PR URL is the primary artifact
- Emit completion signal

### 6. Failure
- If any step fails, transition to `:failed`
- Store error details
- Partial results and artifacts are preserved
- User can retry the entire workflow run

## Data Flow Between Steps

Steps pass data via Runic's fact/provenance system:

```
plan step output:
  %{plan: "1. Add endpoint\n2. Write tests\n3. Update docs",
    files_to_modify: ["lib/api.ex", "test/api_test.exs"]}

  ↓ (becomes a Runic Fact, flows to next node)

implement step input:
  %{plan: "...", files_to_modify: [...]}
  (automatically derived from upstream fact)
```

String interpolation is supported for simple cases:
```
"Implement this plan: {{plan.plan}}"
```

## Agent Handoff Pattern

A key workflow pattern is **agent handoffs** — where different phases of a workflow are handled by different agents, potentially using different LLM models:

```
Phase 1: Research agents (standard model, many parallel calls)
  ↓ handoff: research docs passed as facts
Phase 2: Critical review agent (highest-capability model, single call)
  ↓ handoff: critique + revised design passed as facts
Phase 3: Prompt generation agent (high model, produces N prompts)
  ↓ handoff: prompts passed as facts
Phase 4: Coding agents (model per prompt, sequential execution)
```

This is powered by Runic's DAG structure — each phase is a set of nodes, and the edges between phases carry the accumulated facts (documents, designs, prompts) forward.

## Human-in-the-Loop Patterns

### Approval Gate
Blocks workflow until user approves. Used before destructive operations (commit, PR, deploy). Configurable per workflow.

### Input Request
Blocks workflow and asks the user a question. Used when the agent needs clarification.

### Iteration Loop
User can reject an approval gate and send feedback back to an earlier phase, creating an iterative refinement loop. Used in the research→design pipeline.

### Review Point
Non-blocking — logs output for user review but continues execution. Used for observability checkpoints.

## Workflow Lifecycle Events (PubSub)

Topic: `"jido_code:run:<run_id>"`

| Event | Payload |
|-------|---------|
| `{:step_started, step_id, metadata}` | Step name, inputs |
| `{:step_completed, step_id, result}` | Step name, outputs, duration |
| `{:step_failed, step_id, error}` | Step name, error details |
| `{:approval_requested, step_id, context}` | What to approve, preview data |
| `{:approval_granted, step_id}` | User approved |
| `{:approval_rejected, step_id, reason}` | User rejected |
| `{:run_completed, summary}` | Final status, artifacts, cost |
| `{:run_failed, error}` | Error details |

## Open Questions

1. **Workflow versioning**: when a builtin workflow is updated in a new release, do existing runs continue with the old version? *(Recommendation: yes, version is pinned at run creation)*
2. **Parallel steps**: should the MVP support parallel DAG branches, or only linear chains? *(Recommendation: linear for MVP, parallel in Phase 2 — needed for research fan-out)*
3. **Retry semantics**: per-step retry with backoff, or only full-run retry? *(Recommendation: full-run retry for MVP)*
