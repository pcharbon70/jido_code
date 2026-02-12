# Jido Code — PRD & Specification Index

**Jido Code** is an open-source coding orchestrator built on the [Jido](https://github.com/agentjido/jido) framework. It provides a self-hosted, single-user platform for orchestrating AI coding agents (Claude Code, Ampcode, etc.) through durable, composable workflows — then committing results and opening pull requests automatically.

Jido Code serves as the flagship showcase for the Jido ecosystem: demonstrating how Jido agents, actions, signals, durable workflows (Runic), and sandboxed execution (Forge/Sprites) compose into a real product.

---

## MVP User Journey

```
1. Install & Launch  →  First-run onboarding wizard
2. Configure          →  Set LLM API keys, connect GitHub App, choose environment
3. Import Project     →  Clone repo via GitHub App to local folder or Sprite sandbox
4. Create Workflow    →  Pick a builtin or define custom workflow (Runic DAG)
5. Run Workflow       →  Agents execute in environment, stream output to UI
6. Review & Approve   →  Human-in-the-loop approval gates
7. Ship               →  Auto-commit, push branch, open PR
```

---

## Specs Index

| #      | Document                                                         | Status | Description                                     |
| ------ | ---------------------------------------------------------------- | ------ | ----------------------------------------------- |
| **00** | [Vision & PRD](00_vision_and_prd.md)                             | Draft  | Project vision, target users, principles, scope |
| **01** | [Glossary & Concepts](01_glossary_and_concepts.md)               | Draft  | Terminology and conceptual model                |
| **02** | [Requirements & Scope](02_requirements_and_scope.md)             | Draft  | Hard requirements, MVP cut, non-goals           |
| **10** | [Web UI & Routes](10_web_ui_and_routes.md)                       | Draft  | Information architecture, pages, LiveView       |
| **11** | [Onboarding Flow](11_onboarding_flow.md)                         | Draft  | First-run setup wizard                          |
| **20** | [Ash Domain Model](20_ash_domain_model.md)                       | Draft  | Resources, relationships, persistence           |
| **30** | [Workflow System](30_workflow_system_overview.md)                | Draft  | Runic integration, triggers, authoring          |
| **31** | [Builtin Workflows](31_builtin_workflows.md)                     | Draft  | MVP workflow definitions                        |
| **32** | [Agent & Action Catalog](32_agent_and_action_catalog.md)         | Draft  | Agents, runners, actions inventory              |
| **40** | [Project Environments](40_project_environments.md)               | Draft  | Local vs Sprite workspaces                      |
| **41** | [Forge Integration](41_forge_integration.md)                     | Draft  | Session lifecycle, runners, streaming           |
| **50** | [GitHub Integration](50_github_integration.md)                   | Draft  | GitHub App, repo management, webhooks           |
| **51** | [Git & PR Flow](51_git_and_pr_flow.md)                           | Draft  | Branch strategy, commit, PR automation          |
| **60** | [Security & Auth](60_security_and_auth.md)                       | Draft  | Single-user auth, secrets, threat model         |
| **61** | [Configuration & Deployment](61_configuration_and_deployment.md) | Draft  | Env vars, Fly deployment, local dev             |

---

## Glossary (quick reference)

| Term              | Definition                                                                   |
| ----------------- | ---------------------------------------------------------------------------- |
| **Agent**         | A Jido agent — a stateful entity that processes signals and executes actions |
| **Action**        | A composable, validated unit of work (Jido Action)                           |
| **Workflow**      | A durable DAG of actions orchestrated by Runic                               |
| **Workflow Run**  | A single execution instance of a workflow                                    |
| **Runner**        | A Forge execution adapter (Shell, ClaudeCode, Workflow, Custom)              |
| **Forge Session** | An isolated execution runtime managed by the Forge subsystem                 |
| **Sprite**        | A cloud sandbox container provisioned via the Sprites SDK                    |
| **Signal**        | A typed message envelope for agent communication (Jido Signal)               |
| **Artifact**      | Any output produced by a workflow run (diffs, logs, PR URLs, reports)        |
| **Project**       | A GitHub repository imported into Jido Code                                  |
| **Workspace**     | The execution environment for a project (local folder or sprite)             |

---

## Decisions Log

Decisions that affect multiple specs are recorded here.

| #   | Decision                            | Date | Notes                                                    |
| --- | ----------------------------------- | ---- | -------------------------------------------------------- |
| D1  | Single-user, no multi-tenancy       | —    | Simplifies auth, secrets, and deployment                 |
| D2  | Phoenix 1.8 + Ash + PostgreSQL      | —    | Existing stack                                           |
| D3  | Local + Sprite dual environments    | —    | Forge already supports both via SpriteClient             |
| D4  | jido_runic for durable workflows    | —    | DAG-based, provenance tracking, signal integration       |
| D5  | Dual-mode deployment (Fly + local)  | —    | Cloud-first, local as option                             |
| D6  | Env vars for secrets                | —    | No Cloak for MVP; secrets from environment               |
| D7  | User-created GitHub App             | —    | No private keys in open source; users bring their own    |
| D8  | Code-first workflow authoring       | —    | Visual builder deferred to later phase                   |
| D9  | Per-workflow approval config        | —    | Each workflow definition controls its own approval gates |
| D10 | Multi-phase agent handoff workflows | —    | Research → Review → Prompt Gen → Execution pattern       |

---

## Resolved Decisions

| #   | Question                  | Decision                                                                                    |
| --- | ------------------------- | ------------------------------------------------------------------------------------------- |
| Q1  | Where does Jido Code run? | **Dual-mode**: cloud server (Fly Machine) or local Phoenix app                              |
| Q2  | Secrets management?       | **Environment variables** primarily; no Cloak for MVP                                       |
| Q3  | GitHub App model?         | **Open source, no private keys in source**; users configure their own GitHub App or use PAT |
| Q4  | Workflow authoring UX?    | **Code-first**; visual builder deferred                                                     |
| Q5  | Human approval policy?    | **Per-workflow configurable**                                                               |
| Q6  | GitHub App deployment?    | Users create their own GitHub App (private key stays with user, never in source)            |

## Open Questions

1. **Artifact storage:** First-class diff/patch viewer, or "PR is the artifact"? _(Default: PR is primary, logs stored)_
2. **Issue Bot scope:** Separate workflow type or per-repo configurable "support agent"? _(Default: per-repo support agent)_
