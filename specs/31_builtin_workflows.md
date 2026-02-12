# 31 — Builtin Workflows

## Overview

Jido Code ships with a set of builtin workflow templates that cover common coding tasks. These serve as both useful defaults and reference implementations showing how to build Runic DAG workflows with Jido agents.

---

## Workflow 1: Implement Task

**Name**: `implement_task`
**Category**: Coding
**Description**: Given a task description, plan the implementation, code it using an AI agent, run tests, and open a PR.

### Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `task` | string | yes | What to implement (natural language description) |
| `branch_name` | string | no | Branch name (auto-generated if omitted) |
| `agent` | atom | no | Which coding agent to use (default: `:claude_code`) |
| `test_command` | string | no | Test command (default: auto-detect from project) |
| `context_files` | list | no | Additional files to include as context |

### DAG

```
[plan] → [implement] → [test] → [approve] → [commit_and_pr]
```

### Steps

#### 1. Plan (`JidoCode.Actions.PlanTask`)
- **Runner**: LLM call (via `jido_ai`)
- **Input**: task description, repo structure summary
- **Output**: implementation plan, list of files to modify, estimated complexity
- **Failure**: retry once, then fail run

#### 2. Implement (`JidoCode.Actions.RunCodingAgent`)
- **Runner**: Claude Code (via Forge `ClaudeCode` runner)
- **Input**: plan from step 1, project workspace
- **Output**: modified files, agent conversation transcript
- **Forge Session**: created with project workspace, plan injected as prompt
- **Failure**: capture partial output, fail run

#### 3. Test (`JidoCode.Actions.RunTests`)
- **Runner**: Shell (via Forge `Shell` runner)
- **Input**: test command (auto-detected or from input)
- **Output**: test results (pass/fail, output)
- **On Failure**: 
  - If tests fail → feed failure back to coding agent for one retry iteration
  - If retry fails → proceed to approval with test failure noted

#### 4. Approve (`JidoCode.Actions.RequestApproval`)
- **Type**: Human-in-the-loop gate
- **Presented to user**: 
  - Git diff of all changes
  - Test results
  - Implementation plan
  - Cost so far
- **User actions**: Approve (continue) or Reject (cancel run)

#### 5. Commit & PR (`JidoCode.Actions.CommitAndPR`)
- **Runner**: Shell (git operations)
- **Steps**:
  1. Create branch from default branch
  2. Stage all changes
  3. Commit with generated message
  4. Push branch to origin
  5. Create PR via GitHub API
- **Output**: PR URL, branch name, commit SHA
- **Artifacts**: PR URL stored as artifact

---

## Workflow 2: Fix Failing Tests

**Name**: `fix_failing_tests`
**Category**: Coding
**Description**: Reproduce a test failure, diagnose the issue, fix it, verify the fix, and open a PR.

### Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `test_command` | string | yes | The failing test command (e.g., `mix test test/api_test.exs`) |
| `branch_name` | string | no | Branch name (auto-generated if omitted) |
| `context` | string | no | Additional context about the failure |

### DAG

```
[reproduce] → [diagnose] → [fix] → [verify] → [approve] → [commit_and_pr]
```

### Steps

#### 1. Reproduce (`JidoCode.Actions.ReproduceFailure`)
- **Runner**: Shell
- **Input**: test command
- **Output**: test output, failure details, exit code
- **On Success** (tests pass): abort workflow with "Tests already passing" message

#### 2. Diagnose (`JidoCode.Actions.DiagnoseFailure`)
- **Runner**: LLM call
- **Input**: test output, relevant source files
- **Output**: root cause analysis, suggested fix approach

#### 3. Fix (`JidoCode.Actions.RunCodingAgent`)
- **Runner**: Claude Code
- **Input**: diagnosis, test output, fix instructions
- **Output**: modified files

#### 4. Verify (`JidoCode.Actions.RunTests`)
- **Runner**: Shell
- **Input**: same test command as step 1
- **Output**: test results
- **On Failure**: retry fix step (max 2 attempts), then proceed to approval with failure noted

#### 5. Approve (`JidoCode.Actions.RequestApproval`)
- Same as Implement Task workflow

#### 6. Commit & PR (`JidoCode.Actions.CommitAndPR`)
- Same as Implement Task workflow
- PR title: "fix: [auto-generated from diagnosis]"

---

## Workflow 3: Issue Triage & Research (Phase 2)

**Name**: `issue_triage`
**Category**: Support
**Description**: Triage a GitHub issue, research the root cause, and post a helpful response.

### Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `issue_number` | integer | yes | GitHub issue number |
| `auto_respond` | boolean | no | Whether to auto-post response (default: false) |

### DAG

```
[fetch_issue] → [triage] → [research] → [compose_response] → [approve] → [post_response]
                                ├→ [code_search]
                                ├→ [reproduction]
                                ├→ [root_cause]
                                └→ [pr_search]
```

### Steps

Built on the existing `AgentJido.GithubIssueBot` architecture:

1. **Fetch Issue**: retrieve issue details from GitHub API
2. **Triage**: classify (bug/feature/question/docs), detect needs_info
3. **Research**: fan out to 4 parallel workers (code search, reproduction, root cause, PR search)
4. **Compose Response**: synthesize research into a helpful comment
5. **Approve**: human reviews the proposed response
6. **Post Response**: post comment on the GitHub issue

---

## Workflow 4: Research → Design → Implement Pipeline

**Name**: `research_and_implement`
**Category**: Coding (Advanced)
**Description**: A multi-phase workflow that invests heavily in research and design before generating self-contained coding prompts and executing them sequentially. This is the flagship workflow that showcases agent handoffs, sub-agent spawning, and the full power of Runic DAGs.

### Inputs

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `objective` | string | yes | What you're trying to build/solve |
| `project_context` | string | no | Additional context about the project |
| `research_depth` | atom | no | `:shallow`, `:normal`, `:deep` (default: `:normal`) |
| `review_model` | string | no | High-capability model for critical review (e.g., `"o3-pro"`) |
| `execution_model` | string | no | Model for coding execution (default: `"claude-sonnet-4"`) |
| `branch_name` | string | no | Branch name (auto-generated if omitted) |
| `max_prompts` | integer | no | Max number of execution prompts (default: 20) |

### DAG

This workflow demonstrates **agent handoffs** — each phase produces documents that feed into the next phase, with different agents (and potentially different LLM models) handling each phase.

```
Phase 1: Research & Discovery
  [define_objective]
    → [spawn_research_agents] (fan-out: N sub-agents)
      → [collect_research]
        → [spawn_followup_agents] (fan-out: M sub-agents)
          → [produce_design_docs]
            → [generate_adrs] (optional)
              → [approval_gate_1: "Is the design solid?"]

Phase 2: Critical Review
  → [critical_review] (high-capability model)
    → [adjust_design]
      → [approval_gate_2: "Review adjustments OK?"]

Phase 3: Prompt Generation
  → [generate_prompts] (Claude generates N self-contained prompts)
    → [approval_gate_3: "Review generated prompts?"]

Phase 4: Sequential Execution
  → [execute_prompt_1] → [verify_green_1]
    → [execute_prompt_2] → [verify_green_2]
      → ... (N prompts)
        → [final_verify]
          → [approval_gate_4: "Ship it?"]
            → [commit_and_pr]
```

### Phase 1: Research & Discovery

#### Step 1.1: Define Objective (`JidoCode.Actions.DefineObjective`)
- **Runner**: LLM
- **Input**: `objective`, `project_context`, repo structure
- **Output**: structured objective with scope, constraints, success criteria
- **Model**: standard model

#### Step 1.2: Spawn Research Agents (`JidoCode.Actions.SpawnResearchAgents`)
- **Runner**: Agent handoff (Runic fan-out)
- **Input**: structured objective
- **Output**: N research documents (one per sub-agent)
- **Sub-agents**: each focuses on a different aspect (API design, data model, existing patterns, prior art, edge cases)
- **Key pattern**: this is a **Runic fan-out node** — multiple `ActionNode`s execute in parallel, each producing a fact
- **Model**: standard model (volume work)

#### Step 1.3: Collect & Plan Follow-ups (`JidoCode.Actions.CollectResearch`)
- **Runner**: LLM
- **Input**: all research documents
- **Output**: synthesis + list of follow-up research tasks
- **Model**: high-capability model (synthesis requires reasoning)

#### Step 1.4: Follow-up Research (`JidoCode.Actions.SpawnFollowupAgents`)
- **Runner**: Agent handoff (Runic fan-out)
- **Input**: follow-up task list
- **Output**: M follow-up documents

#### Step 1.5: Produce Design Documents (`JidoCode.Actions.ProduceDesignDocs`)
- **Runner**: LLM
- **Input**: all research + follow-up documents
- **Output**: technical design document, implementation plan, file-by-file change list
- **Artifacts**: design doc stored as artifact

#### Step 1.6: Generate ADRs (Optional) (`JidoCode.Actions.GenerateADRs`)
- **Runner**: LLM
- **Input**: design documents
- **Output**: ADR documents for key architectural decisions
- **Condition**: only runs if `research_depth == :deep`

#### Step 1.7: Approval Gate 1
- **Type**: human-in-the-loop
- **Context**: design docs, ADRs, research summaries
- **User action**: approve (continue), reject (cancel), or **iterate** (send back to research with feedback)
- **Key feature**: the user can add manual curation notes that feed back into the design

### Phase 2: Critical Review

#### Step 2.1: Critical Review (`JidoCode.Actions.CriticalReview`)
- **Runner**: LLM
- **Input**: all design documents
- **Output**: critique document with issues, risks, suggestions
- **Model**: **high-capability model** (e.g., o3-pro, GPT-5.2 XHigh) — this step intentionally uses the most powerful available model for deep reasoning
- **Key principle**: cheap models for volume, expensive models for judgment

#### Step 2.2: Adjust Design (`JidoCode.Actions.AdjustDesign`)
- **Runner**: LLM
- **Input**: design docs + critique
- **Output**: updated design docs (in-place revisions)
- **Model**: standard model

#### Step 2.3: Approval Gate 2
- **Type**: human-in-the-loop
- **Context**: original design, critique, adjusted design (diff view)

### Phase 3: Prompt Generation

#### Step 3.1: Generate Prompts (`JidoCode.Actions.GeneratePrompts`)
- **Runner**: LLM
- **Input**: finalized design docs, implementation plan
- **Output**: ordered list of N self-contained prompt files
- **Key constraints** (each prompt must include):
  - All required reading (source files + docs) with absolute paths
  - All context needed (no assumption of prior context)
  - All implementation instructions
  - Strict TDD requirements (write tests first)
  - Add/update examples
  - All tests pass, no warnings, no errors, no linting issues
- **Bias**: toward many small prompts over fewer large ones (reliability)
- **Artifacts**: each prompt stored as an artifact

#### Step 3.2: Approval Gate 3
- **Type**: human-in-the-loop
- **Context**: list of generated prompts with descriptions
- **User can**: reorder, remove, or request regeneration of specific prompts

### Phase 4: Sequential Execution

#### Step 4.N: Execute Prompt N (`JidoCode.Actions.ExecutePrompt`)
- **Runner**: Coding agent (Claude Code or Ampcode, configurable per prompt)
- **Input**: self-contained prompt file
- **Output**: modified files, test results
- **Key constraint**: code must be green (all tests pass) after each prompt
- **On test failure**: retry the prompt with the failure context (max 2 retries)
- **Model selection**: configurable per prompt type (e.g., Opus for web UI, Codex for backend)

#### Step 4.N+1: Verify Green (`JidoCode.Actions.VerifyGreen`)
- **Runner**: Shell
- **Input**: test/lint/typecheck commands
- **Output**: pass/fail + output
- **On failure**: feed failure back to coding agent for correction

#### Step 4.Final: Final Verification (`JidoCode.Actions.FinalVerify`)
- **Runner**: Shell
- **Input**: full test suite + linting + type checking
- **Output**: comprehensive results

#### Step 4.Final+1: Approval Gate 4
- **Type**: human-in-the-loop
- **Context**: full diff, test results, cost summary
- **User action**: approve (open PR) or reject

#### Step 4.Final+2: Commit & PR
- Same as other workflows

### Key Patterns Demonstrated

| Pattern | Where | Runic Feature |
|---------|-------|---------------|
| **Fan-out** | Research agents (1.2, 1.4) | Parallel `ActionNode` branches |
| **Fan-in** | Collect research (1.3) | Node with multiple upstream dependencies |
| **Agent handoff** | Research → Review → Execution | Different agents/models per phase |
| **Iterative loop** | Approval gate 1 → back to research | Conditional edge back to earlier node |
| **Sequential chain** | Prompt execution (4.N) | Linear DAG segment |
| **Conditional branching** | ADR generation (1.6) | `SignalMatch` gating |
| **Dynamic sub-DAG** | N prompts generate N execution steps | Runtime DAG construction |
| **Model routing** | Different models per phase | Runner config per `ActionNode` |

### Cost & Model Strategy

| Phase | Model Tier | Rationale |
|-------|-----------|-----------|
| Research (1.2, 1.4) | Standard (Sonnet) | Volume work, many parallel calls |
| Synthesis (1.3, 1.5) | High (Opus) | Needs reasoning across multiple docs |
| Critical Review (2.1) | Highest (o3-pro) | Deep reasoning, finding flaws |
| Prompt Generation (3.1) | High (Opus) | Needs to produce precise, correct prompts |
| Code Execution (4.N) | Varies per prompt | Web → Opus; backend → Codex; tests → Sonnet |

---

## Workflow 5: Code Review (Phase 3)

**Name**: `code_review`
**Category**: Support
**Description**: Review a pull request and post feedback.

*(Definition deferred to Phase 3)*

---

## Shared Actions

These actions are reused across multiple workflows:

| Action | Description |
|--------|-------------|
| `JidoCode.Actions.PlanTask` | LLM-powered task planning |
| `JidoCode.Actions.RunCodingAgent` | Execute a coding agent in a Forge session |
| `JidoCode.Actions.RunTests` | Run test suite and parse results |
| `JidoCode.Actions.RequestApproval` | Human-in-the-loop approval gate |
| `JidoCode.Actions.CommitAndPR` | Git commit, push, and PR creation |
| `JidoCode.Actions.ReproduceFailure` | Run a command and capture failure output |
| `JidoCode.Actions.DiagnoseFailure` | LLM-powered failure diagnosis |
| `JidoCode.Actions.FetchGitHubIssue` | Retrieve issue from GitHub API |
| `JidoCode.Actions.DefineObjective` | Structure an objective with scope and criteria |
| `JidoCode.Actions.SpawnResearchAgents` | Fan-out to N parallel research sub-agents |
| `JidoCode.Actions.CollectResearch` | Synthesize research docs, plan follow-ups |
| `JidoCode.Actions.ProduceDesignDocs` | Generate technical design + implementation plan |
| `JidoCode.Actions.GenerateADRs` | Create Architectural Decision Records |
| `JidoCode.Actions.CriticalReview` | High-capability model reviews design for flaws |
| `JidoCode.Actions.AdjustDesign` | Revise design docs based on critique |
| `JidoCode.Actions.GeneratePrompts` | Produce N self-contained coding prompt files |
| `JidoCode.Actions.ExecutePrompt` | Run a single self-contained prompt via coding agent |
| `JidoCode.Actions.VerifyGreen` | Verify tests/lint/types pass after a change |

## Workflow Registration

Builtin workflows are registered at application startup:

```elixir
defmodule JidoCode.Workflows do
  def builtin_workflows do
    [
      JidoCode.Workflows.ImplementTask,
      JidoCode.Workflows.FixFailingTests
    ]
  end

  def seed_builtins do
    for workflow_mod <- builtin_workflows() do
      workflow_mod.register()
    end
  end
end
```

Each workflow module implements a `register/0` function that creates or updates the corresponding `WorkflowDefinition` resource.
