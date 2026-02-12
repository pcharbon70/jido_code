# 40 — Project Environments & Workspaces

## Overview

Every project in Jido Code needs an execution environment — a place where code is cloned, agents run, tests execute, and git operations happen. Jido Code supports two environment types, both conforming to a single **Workspace** interface.

## Environment Types

### Local Environment
- Repo cloned to a directory on the host filesystem
- Commands execute via `System.cmd/3`
- Git operations use the host's git binary
- Coding CLIs (Claude Code, Ampcode) run as local processes
- **Pros**: fast, no network overhead, uses existing tools
- **Cons**: no isolation, shares host resources, requires tools installed on host
- **MVP**: primary environment

### Sprite Environment (Phase 2)
- Repo cloned inside a Sprites cloud sandbox container
- Commands execute via Sprites SDK API
- Isolated filesystem and network
- Tools pre-installed in container image
- **Pros**: isolated, reproducible, can run untrusted code safely
- **Cons**: network latency, API overhead, container provisioning time
- **Implementation**: via existing `AgentJido.Forge.SpriteClient.Live`

## Workspace Interface

Both environments implement a common interface that workflows and agents interact with:

```elixir
defmodule JidoCode.Workspace do
  @type t :: %__MODULE__{
    type: :local | :sprite,
    project_id: String.t(),
    repo_path: String.t(),
    client: term()  # SpriteClient or LocalClient
  }

  @callback exec(workspace, command :: String.t(), opts :: keyword()) ::
    {output :: String.t(), exit_code :: non_neg_integer()}

  @callback cmd(workspace, program :: String.t(), args :: [String.t()], opts :: keyword()) ::
    {output :: String.t(), exit_code :: non_neg_integer()}

  @callback write_file(workspace, path :: String.t(), content :: String.t()) :: :ok | {:error, term()}

  @callback read_file(workspace, path :: String.t()) :: {:ok, String.t()} | {:error, term()}

  @callback file_exists?(workspace, path :: String.t()) :: boolean()

  @callback list_files(workspace, path :: String.t()) :: {:ok, [String.t()]} | {:error, term()}

  @callback inject_env(workspace, env :: map()) :: :ok | {:error, term()}

  @callback git_status(workspace) :: {:ok, String.t()} | {:error, term()}

  @callback destroy(workspace) :: :ok
end
```

### Local Implementation

```elixir
defmodule JidoCode.Workspace.Local do
  @behaviour JidoCode.Workspace

  # exec → System.cmd(cmd, [], cd: repo_path)
  # write_file → File.write(Path.join(repo_path, path), content)
  # inject_env → sets env vars for subsequent commands
  # destroy → optionally rm -rf the workspace dir
end
```

### Sprite Implementation

```elixir
defmodule JidoCode.Workspace.Sprite do
  @behaviour JidoCode.Workspace

  # Delegates to AgentJido.Forge.SpriteClient.Live
  # exec → SpriteClient.exec(client, cmd, opts)
  # write_file → SpriteClient.write_file(client, path, content)
  # destroy → SpriteClient.destroy(client, session_id)
end
```

## Workspace Lifecycle

### Provisioning

```
Project Created
  │
  ├─ Local: mkdir workspace_root/project_name/
  │         git clone <repo_url> .
  │         
  └─ Sprite: SpriteClient.create(sprite_spec)
             SpriteClient.exec("git clone <repo_url> /app")
```

### Per-Run Setup

Before each workflow run:
1. **Sync**: pull latest from default branch
2. **Clean**: ensure working tree is clean (`git checkout -- .`, `git clean -fd`)
3. **Branch**: create a fresh branch from default branch
4. **Inject Secrets**: set environment variables (API keys, tokens — read from env vars at runtime)
5. **Bootstrap**: install dependencies if needed (`mix deps.get`, `npm install`, etc.)

### Cleanup

After a workflow run completes (or fails):
- **Local**: leave the workspace in place (user may want to inspect)
- **Sprite**: destroy the sprite (ephemeral by default, configurable)

## Secrets Injection

Workspaces need secrets injected as environment variables. These are read from the host's env vars at runtime:

| Secret | Source Env Var | Example |
|--------|---------------|---------|
| LLM API keys | `ANTHROPIC_API_KEY` | `sk-ant-...` |
| GitHub token | Generated from `GITHUB_APP_PRIVATE_KEY` | `ghs_...` |
| Project secrets | Per-project env var mappings | `DATABASE_URL=postgres://...` |

**Security rules**:
- Secrets are injected at run start, never persisted to disk in the workspace
- For sprites: injected via `SpriteClient.inject_env/2`
- For local: passed as env to `System.cmd/3` options
- Secrets are never included in commit diffs or agent prompts
- Secrets are redacted from log output before persistence

## Git Authentication

For git push/PR operations, the workspace needs push access:

### GitHub App Token (primary)
- Generate an installation access token via GitHub App API (using `GITHUB_APP_PRIVATE_KEY` env var)
- Configure git to use the token: `git remote set-url origin https://x-access-token:<token>@github.com/owner/repo.git`
- Tokens expire (1 hour) — refresh before long-running operations

### Personal Access Token (fallback)
- Use the `GITHUB_PAT` env var directly
- Configure similarly to App token

## Directory Layout

### Local Workspace
```
~/.jido_code/workspaces/
└── owner-repo/              # one dir per project
    ├── .git/
    ├── ... (repo contents)
    └── .jido_code/          # Jido Code metadata (gitignored)
        ├── workspace.json   # workspace config
        └── runs/            # per-run logs (optional)
```

### Sprite Workspace
```
/app/                        # repo root (inside sprite)
├── .git/
├── ... (repo contents)
└── /var/local/forge/        # Forge working directory
    ├── session/
    ├── templates/
    └── .claude/
```

## Project-Level Configuration

Each project can override defaults:

```elixir
%Project{
  environment_type: :local,
  local_path: "/home/user/.jido_code/workspaces/myorg-myrepo",
  sprite_spec: nil,  # or %{image: "ubuntu:latest", resources: %{cpu: 2, memory: "4Gi"}}
  settings: %{
    "test_command" => "mix test",
    "build_command" => "mix compile",
    "bootstrap_commands" => ["mix deps.get"],
    "default_branch" => "main",
    "branch_prefix" => "jido-code/"
  }
}
```

## Open Questions

1. **Workspace reuse vs fresh**: should each workflow run get a fresh clone, or reuse the existing workspace with a `git checkout`? *(Recommendation: reuse with clean checkout for local; fresh sprite per run)*
2. **Concurrent runs on same project**: if two workflows target the same project, do they share a workspace? *(Recommendation: no, create separate workspaces or queue runs)*
3. **Large repos**: should we support shallow clones (`--depth 1`) for large repos? *(Recommendation: yes, configurable per project)*
