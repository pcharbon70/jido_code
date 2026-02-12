# 70 — Rename Plan: agent_jido → jido_code

## Overview

The `agent_jido` project is being renamed to `jido_code` to reflect its focused purpose as a coding orchestrator. This document tracks the naming decisions and migration plan.

## Naming Decisions

| Item | Current | New |
|------|---------|-----|
| Project name | `agent_jido` | `jido_code` |
| App name (OTP) | `:agent_jido` | `:jido_code` |
| Root module | `AgentJido` | `JidoCode` |
| Web module | `AgentJidoWeb` | `JidoCodeWeb` |
| Repo module | `AgentJido.Repo` | `JidoCode.Repo` |
| Source dir | `lib/agent_jido/` | `lib/jido_code/` |
| Web dir | `lib/agent_jido_web/` | `lib/jido_code_web/` |
| Test dir | `test/agent_jido/` | `test/jido_code/` |
| Config keys | `config :agent_jido` | `config :jido_code` |
| DB name | `agent_jido_dev` / `_test` / `_prod` | `jido_code_dev` / `_test` / `_prod` |
| GitHub repo | `agentjido/agent_jido` | `agentjido/jido_code` |
| Endpoint | `AgentJidoWeb.Endpoint` | `JidoCodeWeb.Endpoint` |

## Module Namespace Mapping

### Core
| Current | New |
|---------|-----|
| `AgentJido` | `JidoCode` |
| `AgentJido.Application` | `JidoCode.Application` |
| `AgentJido.Repo` | `JidoCode.Repo` |
| `AgentJido.Error` | `JidoCode.Error` |
| `AgentJido.Secrets` | `JidoCode.Secrets` |
| `AgentJido.Accounts` | `JidoCode.Accounts` |
| `AgentJido.Jido` | `JidoCode.Jido` |

### Forge
| Current | New |
|---------|-----|
| `AgentJido.Forge` | `JidoCode.Forge` |
| `AgentJido.Forge.Manager` | `JidoCode.Forge.Manager` |
| `AgentJido.Forge.SpriteSession` | `JidoCode.Forge.SpriteSession` |
| `AgentJido.Forge.SpriteClient` | `JidoCode.Forge.SpriteClient` |
| `AgentJido.Forge.Runner` | `JidoCode.Forge.Runner` |
| `AgentJido.Forge.Runners.*` | `JidoCode.Forge.Runners.*` |
| `AgentJido.Forge.Domain` | `JidoCode.Forge.Domain` |

### GitHub
| Current | New |
|---------|-----|
| `AgentJido.GitHub` | `JidoCode.GitHub` |
| `AgentJido.GitHub.Repo` | `JidoCode.GitHub.Repo` |
| `AgentJido.GitHub.WebhookDelivery` | `JidoCode.GitHub.WebhookDelivery` |
| `AgentJido.GitHub.IssueAnalysis` | `JidoCode.GitHub.IssueAnalysis` |

### GitHub Issue Bot
| Current | New |
|---------|-----|
| `AgentJido.GithubIssueBot.*` | `JidoCode.Agents.IssueBot.*` |

### Folio (repurposed)
| Current | New |
|---------|-----|
| `AgentJido.Folio` | `JidoCode.Projects` (repurposed) |
| `AgentJido.Folio.Project` | `JidoCode.Projects.Project` |

### Web
| Current | New |
|---------|-----|
| `AgentJidoWeb` | `JidoCodeWeb` |
| `AgentJidoWeb.Router` | `JidoCodeWeb.Router` |
| `AgentJidoWeb.Endpoint` | `JidoCodeWeb.Endpoint` |
| `AgentJidoWeb.*Live` | `JidoCodeWeb.*Live` |

## New Modules (not from rename)

These are new modules that will be created as part of the Jido Code vision:

| Module | Purpose |
|--------|---------|
| `JidoCode.Setup` | Ash domain for onboarding/config |
| `JidoCode.Setup.SystemConfig` | Singleton system configuration |
| `JidoCode.Setup.Credential` | Env var credential metadata tracking |
| `JidoCode.Orchestration` | Ash domain for workflows |
| `JidoCode.Orchestration.WorkflowDefinition` | Workflow templates |
| `JidoCode.Orchestration.WorkflowRun` | Workflow executions |
| `JidoCode.Orchestration.Artifact` | Run outputs |
| `JidoCode.Orchestration.PullRequest` | PR records |
| `JidoCode.Workspace` | Workspace interface |
| `JidoCode.Workspace.Local` | Local filesystem workspace |
| `JidoCode.Workspace.Sprite` | Sprite cloud workspace |
| `JidoCode.Workflows.*` | Builtin workflow definitions |
| `JidoCode.Actions.*` | Shared actions |
| `JidoCode.Agents.*` | Agent definitions |
| `JidoCode.Secrets.Redactor` | Secret pattern redaction |
| `JidoCode.Plugs.OptionalBasicAuth` | Optional admin password plug |

## Migration Approach

### Phase 1: Docs First (now)
- All spec documents use the new `JidoCode` naming
- No code changes yet
- README updated to reference new name

### Phase 2: Code Rename (before MVP development)
- Use `mix igniter` or find-and-replace for bulk rename
- Update `mix.exs`: app name, module names, paths
- Rename `lib/agent_jido/` → `lib/jido_code/`
- Rename `lib/agent_jido_web/` → `lib/jido_code_web/`
- Rename `test/agent_jido/` → `test/jido_code/`
- Update all module definitions
- Update all `config/*.exs` files
- Update `Dockerfile`, `fly.toml`, etc.
- Run `mix compile` to verify
- Run `mix test` to verify

### Phase 3: GitHub Repo Rename
- Rename GitHub repo `agent_jido` → `jido_code`
- Update all external references
- Set up redirect on old repo name

## Compatibility Notes

- The `jido_workspace` subtree config (`config/workspace.exs`) references `agent_jido` — update the project entry
- Other ecosystem packages should not depend on `agent_jido` directly (it's an application, not a library)
- The existing `AgentJido.Forge` is referenced in the Forge overview doc — this is carried forward as `JidoCode.Forge`

## Checklist

- [ ] Update spec documents (done)
- [ ] Rename `mix.exs` app and modules
- [ ] Rename source directories
- [ ] Find-replace all module references
- [ ] Update config files
- [ ] Update deployment files (Dockerfile, fly.toml, Procfile)
- [ ] Update README
- [ ] Update AGENTS.md
- [ ] Run compilation check
- [ ] Run test suite
- [ ] Rename GitHub repo
- [ ] Update workspace config
