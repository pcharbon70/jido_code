# 41 — Forge Integration

## Overview

Forge is the execution engine that powers Jido Code's agent runs. It provisions isolated environments (local or sprite), runs coding agents in iteration loops, streams output in real-time, and manages session lifecycle.

## How Workflows Use Forge

When a workflow step requires executing a coding agent or shell command, it creates a **Forge Session**:

```
Workflow Step (Runic ActionNode)
  → CodingOrchestrator Agent
    → Creates Forge Session (with runner + workspace)
      → Runner executes iterations
        → Output streamed via PubSub
      → Session completes
    → Result fed back to workflow DAG
  → Next step
```

## Session-to-Workflow Mapping

| Workflow Concept           | Forge Concept                                  |
| -------------------------- | ---------------------------------------------- |
| Workflow Run               | May create 1+ Forge Sessions                   |
| Workflow Step (coding)     | 1 Forge Session with ClaudeCode/Ampcode runner |
| Workflow Step (test/shell) | 1 Forge Session with Shell runner              |
| Workflow Step (LLM-only)   | No Forge Session (direct `jido_ai` call)       |
| Workflow Step (approval)   | No Forge Session (signal-based)                |

## Runner Configuration per Workflow Step

### Claude Code Runner

```elixir
%{
  runner: :claude_code,
  runner_config: %{
    model: "claude-sonnet-4-20250514",
    max_turns: 200,
    max_budget: 10.0,
    prompt_template: plan_from_previous_step,
    context_template: project_context,
    claude_settings: %{...}
  },
  sprite: workspace_spec,
  bootstrap: [
    %{type: :exec, command: "cd /app && git checkout -b #{branch_name}"}
  ],
  env: %{
    "ANTHROPIC_API_KEY" => System.get_env("ANTHROPIC_API_KEY"),
    "HOME" => "/var/local/forge"
  }
}
```

### Shell Runner

```elixir
%{
  runner: :shell,
  runner_config: %{
    command: "cd /app && mix test"
  },
  env: %{
    "MIX_ENV" => "test"
  }
}
```

### Ampcode Runner (Phase 2)

```elixir
%{
  runner: :ampcode,
  runner_config: %{
    task: task_description,
    model: "claude-sonnet-4-20250514",
    cwd: "/app"
  }
}
```

## Streaming Output to LiveView

Forge sessions broadcast output via PubSub. The workflow run UI subscribes to these topics:

```
forge:session:<session_id>  →  {:output, %{text: "...", exit_code: nil}}
                            →  {:status, %{state: :running, iteration: 3}}
                            →  {:needs_input, %{prompt: "..."}}
                            →  {:stopped, :normal}
```

The `RunDetail` LiveView subscribes to:

1. `jido_code:run:<run_id>` — workflow-level events (step transitions)
2. `forge:session:<session_id>` — active session output (changes as steps progress)

When the active step changes, the LiveView unsubscribes from the old session and subscribes to the new one.

## Session Lifecycle in Workflow Context

### 1. Step Starts

- Workflow engine reaches a coding/shell step
- `JidoCode.Forge.start_session/2` called with step config
- Session provisions workspace (or reuses existing for local)
- Session runs bootstrap commands

### 2. Execution

- Runner executes iterations
- For `claude_code`: single long iteration (until Claude finishes or hits max_turns)
- For `shell`: single iteration (command runs to completion)
- Output streamed to PubSub

### 3. Step Completes

- Session returns result to workflow engine
- Result is stored as a Runic fact
- Artifacts extracted (diff, logs, cost data)
- Session may be kept alive (for subsequent steps in same workspace) or stopped

### 4. Cleanup

- On workflow completion/failure: all associated sessions are stopped
- Sprite sessions destroy their containers
- Local sessions leave workspace in place

## Concurrency

Default limits (single-user, but can run parallel workflows):

| Limit                     | Default | Notes                                |
| ------------------------- | ------- | ------------------------------------ |
| Max total sessions        | 10      | Lower than original 50 (single user) |
| Max `claude_code` runners | 3       | LLM API rate limits                  |
| Max `shell` runners       | 5       |                                      |
| Max `ampcode` runners     | 3       |                                      |

Configurable via `SystemConfig`.

## Error Handling

| Error                       | Handling                                                    |
| --------------------------- | ----------------------------------------------------------- |
| Session startup failure     | Retry once, then fail the workflow step                     |
| Runner iteration timeout    | Configurable timeout, fail step on exceed                   |
| Sprite provisioning failure | Retry once, then fail step                                  |
| Output parsing error        | Log warning, continue (non-fatal)                           |
| Session crash               | GenServer restarts via supervisor; workflow step sees error |

## Checkpoint/Resume

Current status: **partially implemented** in existing Forge code.

For MVP:

- Checkpoints are not relied upon
- If a session crashes mid-step, the step is marked as failed
- User can retry the entire workflow run

For Phase 2:

- Implement session checkpointing so long-running coding agent sessions can resume
- Store checkpoint in Ash `Checkpoint` resource

## Forge Module Mapping (after rename)

| Current                         | After Rename                   |
| ------------------------------- | ------------------------------ |
| `AgentJido.Forge`               | `JidoCode.Forge`               |
| `AgentJido.Forge.Manager`       | `JidoCode.Forge.Manager`       |
| `AgentJido.Forge.SpriteSession` | `JidoCode.Forge.SpriteSession` |
| `AgentJido.Forge.SpriteClient`  | `JidoCode.Forge.SpriteClient`  |
| `AgentJido.Forge.Runner`        | `JidoCode.Forge.Runner`        |
| `AgentJido.Forge.Runners.*`     | `JidoCode.Forge.Runners.*`     |
