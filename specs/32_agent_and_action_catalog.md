# 32 — Agent & Action Catalog

## Overview

This document catalogs all Jido agents and actions that Jido Code will implement or wrap. Agents are stateful entities that orchestrate work; actions are the atomic units of work they execute.

---

## Agents

### Coding Agents

#### `JidoCode.Agents.CodingOrchestrator`
**Role**: Owns a workflow run lifecycle. Receives signals from the workflow engine and dispatches work to the appropriate runner/agent.

- **Strategy**: `JidoRunic.Strategy` (DAG-driven)
- **Signals In**: `workflow.run.start`, `step.completed`, `step.failed`, `approval.granted`, `approval.rejected`
- **Signals Out**: `run.completed`, `run.failed`, `artifact.produced`
- **State**: current workflow run, step results, forge session references
- **Failure Mode**: logs error, transitions run to `:failed`, preserves partial artifacts

#### `JidoCode.Agents.ClaudeCodeAgent`
**Role**: Wraps the Claude Code CLI for execution within a Forge session. Manages prompt construction, iteration loops, and output parsing.

- **Runner**: `JidoCode.Forge.Runners.ClaudeCode` (existing)
- **Signals In**: `coding.task.start` (with plan, context, workspace)
- **Signals Out**: `coding.task.completed` (with diff, transcript, cost), `coding.task.failed`
- **Configuration**: model, max_turns, max_budget, system prompt
- **Failure Mode**: capture partial output, report error with last known state

#### `JidoCode.Agents.AmpcodeAgent` (Phase 2)
**Role**: Wraps the Ampcode CLI. Similar interface to ClaudeCodeAgent.

- **Runner**: `JidoCode.Forge.Runners.Ampcode` (to be built)
- **Signals In/Out**: same pattern as ClaudeCodeAgent
- **Notes**: needs investigation of Ampcode CLI interface and output format

### Support Agents

#### `JidoCode.Agents.GitHubIssueBot`
**Role**: Monitors GitHub issues for configured repos. Triages, researches, and optionally responds. Built on the existing `AgentJido.GithubIssueBot` architecture.

- **Strategy**: multi-phase coordinator (existing pattern)
- **Triggers**: GitHub webhook `issues.opened`, `issues.edited`
- **Sub-agents**: TriageAgent, ResearchCoordinator (with CodeSearch, Reproduction, RootCause, PRSearch workers)
- **Signals In**: `issue.opened`, `issue.edited`
- **Signals Out**: `triage.completed`, `research.completed`, `response.ready`
- **Configuration per project**:
  - `enabled`: boolean
  - `auto_respond`: boolean (post comment without approval)
  - `labels_to_watch`: list of label filters
  - `ignore_labels`: list of labels to skip
  - `response_style`: `:helpful` | `:concise` | `:detailed`
- **Failure Mode**: log error, don't post anything (safe default)

#### `JidoCode.Agents.PRReviewBot` (Phase 3)
**Role**: Reviews pull requests and posts feedback.

#### `JidoCode.Agents.DependencyBot` (Phase 3)
**Role**: Monitors dependencies and opens update PRs.

### Research & Design Agents

#### `JidoCode.Agents.ResearchOrchestrator`
**Role**: Coordinates the multi-phase research → design → implement pipeline. Manages sub-agent spawning, document collection, and phase transitions with agent handoffs.

- **Strategy**: `JidoRunic.Strategy` (DAG-driven with fan-out/fan-in)
- **Signals In**: `research.start`, `research.doc.produced`, `design.review.complete`
- **Signals Out**: `research.phase.complete`, `design.finalized`, `prompts.generated`
- **State**: accumulated research documents, design docs, generated prompts
- **Key feature**: spawns sub-agents dynamically based on the objective (Runic fan-out nodes)
- **Model routing**: selects different LLM models per phase (standard for research, high for synthesis/review)

#### `JidoCode.Agents.ResearchAgent`
**Role**: A spawned sub-agent that researches a specific aspect of a problem. Produces a research document. Multiple instances run in parallel.

- **Strategy**: single-shot (one LLM call per agent)
- **Signals In**: `research.task.assigned` (with focus area, context)
- **Signals Out**: `research.doc.produced` (with document content)
- **Configuration**: focus area (API design, data model, prior art, edge cases, etc.)
- **Ephemeral**: destroyed after producing its document

#### `JidoCode.Agents.CriticalReviewer`
**Role**: Uses a high-capability model to critically review design documents. Finds flaws, risks, missing considerations.

- **Strategy**: single-shot
- **Signals In**: `review.requested` (with design docs)
- **Signals Out**: `review.completed` (with critique document)
- **Model**: intentionally the highest-capability model available (o3-pro, etc.)
- **Key principle**: spend on judgment, save on volume

#### `JidoCode.Agents.PromptGenerator`
**Role**: Takes finalized design documents and produces N self-contained coding prompt files. Each prompt is designed to be executed by a fresh coding agent with no assumed prior context.

- **Strategy**: single-shot (but produces multiple outputs)
- **Signals In**: `prompts.generate` (with design docs, implementation plan)
- **Signals Out**: `prompts.generated` (with ordered list of prompt files)
- **Key constraints**: each prompt is self-contained, includes TDD requirements, specifies exact files to read/modify
- **Bias**: many small prompts > few large prompts (reliability)

---

## Actions

### Project Management Actions

#### `JidoCode.Actions.CloneRepo`
- **Input**: `%{github_full_name, branch, workspace_path | sprite_spec}`
- **Output**: `%{local_path, commit_sha, branch}`
- **Side effects**: clones repo to workspace
- **Runner**: Shell

#### `JidoCode.Actions.SyncRepo`
- **Input**: `%{project_id}`
- **Output**: `%{commit_sha, updated_files_count}`
- **Side effects**: `git pull` in workspace
- **Runner**: Shell

#### `JidoCode.Actions.DetectProjectType`
- **Input**: `%{workspace_path}`
- **Output**: `%{language, framework, test_command, build_command, package_manager}`
- **Side effects**: none (reads filesystem)
- **Runner**: Shell + heuristics

### Planning Actions

#### `JidoCode.Actions.PlanTask`
- **Input**: `%{task, repo_structure, context_files}`
- **Output**: `%{plan, files_to_modify, estimated_complexity, approach}`
- **Side effects**: LLM API call
- **Runner**: LLM (via `jido_ai`)

#### `JidoCode.Actions.DiagnoseFailure`
- **Input**: `%{test_output, source_files, error_messages}`
- **Output**: `%{root_cause, suggested_fix, confidence, evidence}`
- **Side effects**: LLM API call
- **Runner**: LLM (via `jido_ai`)

### Execution Actions

#### `JidoCode.Actions.RunCodingAgent`
- **Input**: `%{agent, plan, workspace, config}`
- **Output**: `%{modified_files, diff, transcript, cost_usd, duration_ms}`
- **Side effects**: creates Forge session, runs coding CLI
- **Runner**: ClaudeCode / Ampcode (via Forge)

#### `JidoCode.Actions.RunTests`
- **Input**: `%{test_command, workspace_path}`
- **Output**: `%{passed, output, exit_code, test_count, failure_count}`
- **Side effects**: runs tests in workspace
- **Runner**: Shell (via Forge)

#### `JidoCode.Actions.ReproduceFailure`
- **Input**: `%{command, workspace_path}`
- **Output**: `%{output, exit_code, failure_confirmed}`
- **Side effects**: runs command
- **Runner**: Shell

### Git & PR Actions

#### `JidoCode.Actions.CreateBranch`
- **Input**: `%{workspace_path, branch_name, base_branch}`
- **Output**: `%{branch_name, created}`
- **Runner**: Shell (`git checkout -b`)

#### `JidoCode.Actions.CommitChanges`
- **Input**: `%{workspace_path, message, author}`
- **Output**: `%{commit_sha, files_changed, insertions, deletions}`
- **Runner**: Shell (`git add`, `git commit`)

#### `JidoCode.Actions.PushBranch`
- **Input**: `%{workspace_path, branch_name, remote}`
- **Output**: `%{pushed, remote_url}`
- **Runner**: Shell (`git push`)

#### `JidoCode.Actions.CreatePullRequest`
- **Input**: `%{project_id, branch_name, title, body, base_branch}`
- **Output**: `%{pr_number, pr_url, pr_html_url}`
- **Side effects**: GitHub API call
- **Runner**: HTTP (via `Req`)

#### `JidoCode.Actions.CommitAndPR`
- **Input**: `%{workspace_path, project_id, branch_name, title, body}`
- **Output**: `%{commit_sha, pr_number, pr_url}`
- **Composed of**: CreateBranch → CommitChanges → PushBranch → CreatePullRequest

### Research & Design Actions

#### `JidoCode.Actions.DefineObjective`
- **Input**: `%{objective, project_context, repo_structure}`
- **Output**: `%{structured_objective, scope, constraints, success_criteria, research_areas}`
- **Side effects**: LLM API call
- **Runner**: LLM (via `jido_ai`)

#### `JidoCode.Actions.SpawnResearchAgents`
- **Input**: `%{structured_objective, research_areas}`
- **Output**: `%{research_docs: [%{area, content, sources}]}`
- **Side effects**: spawns N parallel LLM calls (one per research area)
- **Runner**: LLM fan-out (via Runic parallel branches)
- **Model**: standard tier (volume work)

#### `JidoCode.Actions.CollectResearch`
- **Input**: `%{research_docs, structured_objective}`
- **Output**: `%{synthesis, followup_tasks, gaps_identified}`
- **Side effects**: LLM API call
- **Runner**: LLM (via `jido_ai`)
- **Model**: high tier (synthesis requires reasoning)

#### `JidoCode.Actions.ProduceDesignDocs`
- **Input**: `%{research_docs, followup_docs, structured_objective}`
- **Output**: `%{design_doc, implementation_plan, file_change_list}`
- **Artifacts**: design document stored as artifact
- **Runner**: LLM (via `jido_ai`)

#### `JidoCode.Actions.GenerateADRs`
- **Input**: `%{design_doc, key_decisions}`
- **Output**: `%{adrs: [%{title, context, decision, consequences}]}`
- **Runner**: LLM (via `jido_ai`)
- **Conditional**: only runs when `research_depth == :deep`

#### `JidoCode.Actions.CriticalReview`
- **Input**: `%{design_doc, implementation_plan, adrs}`
- **Output**: `%{critique, issues, risks, suggestions, confidence}`
- **Runner**: LLM (via `jido_ai`)
- **Model**: **highest available** (o3-pro, GPT-5.2 XHigh, etc.)

#### `JidoCode.Actions.AdjustDesign`
- **Input**: `%{design_doc, critique}`
- **Output**: `%{updated_design_doc, changes_made, issues_addressed}`
- **Runner**: LLM (via `jido_ai`)

#### `JidoCode.Actions.GeneratePrompts`
- **Input**: `%{design_doc, implementation_plan, file_change_list, max_prompts}`
- **Output**: `%{prompts: [%{order, title, content, target_files, model_hint}]}`
- **Each prompt includes**: required reading paths, full context, TDD requirements, success criteria
- **Runner**: LLM (via `jido_ai`)
- **Model**: high tier (precision matters)

#### `JidoCode.Actions.ExecutePrompt`
- **Input**: `%{prompt_content, workspace, model, agent_type}`
- **Output**: `%{modified_files, diff, transcript, cost_usd}`
- **Runner**: Coding agent (ClaudeCode or Ampcode via Forge)
- **Model**: configurable per prompt (from `model_hint`)

#### `JidoCode.Actions.VerifyGreen`
- **Input**: `%{workspace_path, commands: [test_cmd, lint_cmd, typecheck_cmd]}`
- **Output**: `%{all_passed, results: [%{command, passed, output}]}`
- **Runner**: Shell (via Forge)

### Approval Actions

#### `JidoCode.Actions.RequestApproval`
- **Input**: `%{context, diff, test_results, cost_so_far}`
- **Output**: `%{approved, reason}` (blocks until user responds)
- **Side effects**: emits PubSub event for UI, transitions run to `:awaiting_approval`
- **Runner**: none (signal-based, waits for user input)

### GitHub Actions

#### `JidoCode.Actions.FetchGitHubIssue`
- **Input**: `%{project_id, issue_number}`
- **Output**: `%{title, body, labels, author, created_at, comments}`
- **Runner**: HTTP (via `Req`)

#### `JidoCode.Actions.PostGitHubComment`
- **Input**: `%{project_id, issue_number, body}`
- **Output**: `%{comment_id, comment_url}`
- **Runner**: HTTP (via `Req`)

#### `JidoCode.Actions.SearchGitHubCode`
- **Input**: `%{project_id, query, file_extensions}`
- **Output**: `%{results: [%{path, snippet, score}]}`
- **Runner**: HTTP (GitHub Search API)

---

## Action Registration

All actions use `Jido.Action` with declared schemas:

```elixir
defmodule JidoCode.Actions.PlanTask do
  use Jido.Action,
    name: "plan_task",
    description: "Create an implementation plan for a coding task",
    schema: [
      task: [type: :string, required: true, doc: "Task description"],
      repo_structure: [type: :string, doc: "Repository file tree"],
      context_files: [type: {:list, :string}, default: [], doc: "Additional context files"]
    ]

  def run(params, context) do
    # LLM call to generate plan
    {:ok, %{plan: "...", files_to_modify: [...], estimated_complexity: :medium}}
  end
end
```

## Agent-to-Runner Mapping

| Agent | Primary Runner | Forge Session? |
|-------|---------------|----------------|
| CodingOrchestrator | none (coordinator) | No |
| ClaudeCodeAgent | `Runners.ClaudeCode` | Yes |
| AmpcodeAgent | `Runners.Ampcode` | Yes |
| ResearchOrchestrator | none (coordinator) | No |
| ResearchAgent | none (LLM only) | No |
| CriticalReviewer | none (LLM only) | No |
| PromptGenerator | none (LLM only) | No |
| GitHubIssueBot | none (LLM + HTTP) | No |
| PRReviewBot | none (LLM + HTTP) | No |
