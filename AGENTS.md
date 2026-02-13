# AGENTS.md

## Mission
Implement the MVP backlog in `specs/stories` with disciplined, atomic loops.
One loop = one story card (`ST-*`) only.

## Product Context
JidoCode is an Elixir/Phoenix LiveView app for orchestrating AI-assisted coding workflows.

Current codebase already includes:
- Forge session runtime (`lib/jido_code/forge`) with streaming LiveView UI.
- GitHub Issue Bot agents (`lib/jido_code/github_issue_bot`) and GitHub domain resources.
- Ash + AshAuthentication based auth and app shell routes.

Planned MVP scope is defined in `specs/` and decomposed into 106 stories in `specs/stories/`.

## Canonical Sources
- Product/spec index: `specs/README.md`
- Story backlog source of truth: `specs/stories/README.md`
- Story traceability: `specs/stories/00_traceability_matrix.md`
- Domain story files: `specs/stories/01_*.md` .. `12_*.md`
- Implementation status and architecture: `README.md`

## Story Loop Contract (Ralph Wiggum Loop)
For backlog automation, follow this exact contract:

1. Select exactly one story ID (`ST-...`).
2. Read that full story card from its domain file.
3. Read matching row in `specs/stories/00_traceability_matrix.md`.
4. Implement only what is required for that story's acceptance criteria.
5. Add/update tests for that story.
6. Run `mix precommit` and fix all failures.
7. Commit exactly once for that story.
8. Push commit to remote branch.
9. Do not open a PR.

Rules:
- Never batch multiple story IDs in one loop.
- Respect story dependencies listed in `#### Dependencies`.
- If blocked, stop and report blocker clearly.

## Loop Automation Script
Use `scripts/ralph_wiggum_loop.sh` to execute the one-story loop with Codex CLI.

Recommended start:
```bash
scripts/ralph_wiggum_loop.sh --dry-run
scripts/ralph_wiggum_loop.sh --start-at ST-ONB-001
```

Important script behaviors:
- Reads story cards from `specs/stories/[0-9][0-9]_*.md` in file order.
- Uses one `codex exec` run per story.
- Runs `mix precommit` (unless explicitly skipped).
- Commits once per story and pushes branch (unless `--no-push`).

## Commit Policy
- Commit format: `feat(story): ST-XXX-NNN <short title>`
- Include only story-relevant files.
- Push after each successful story loop.
- No PR creation during this automation run.

## Engineering Guardrails

### Elixir and Phoenix
- Use `Req` for HTTP calls. Do not introduce `HTTPoison`, `Tesla`, or `:httpc`.
- Do not use `String.to_atom/1` on user input.
- Do not use map-access syntax on structs (`changeset[:field]`); use struct fields or APIs like `Ecto.Changeset.get_field/2`.
- Keep one module per file.
- Prefer `Task.async_stream/3` with back-pressure for concurrent enumeration.

### LiveView and HEEx
- Start LiveView templates with `<Layouts.app flash={@flash} ...>`.
- Pass `current_scope` to `<Layouts.app>` where authenticated scope is needed.
- Never call `<.flash_group>` outside the layouts module.
- Use `<.input>` from core components for forms when available.
- Use `<.icon>` for hero icons.
- Use HEEx-compatible interpolation and class list syntax.
- Do not use deprecated `live_redirect`/`live_patch`; use `<.link navigate={...}>`, `<.link patch={...}>`, `push_navigate`, `push_patch`.
- Prefer LiveView streams for collection rendering and updates.

### JS and CSS
- Tailwind v4 import style in `assets/css/app.css` must stay:
  - `@import "tailwindcss" source(none);`
  - `@source "../css";`
  - `@source "../js";`
  - `@source "../../lib/jido_code_web";`
- Do not use inline `<script>` tags in HEEx.
- For LiveView hooks, use colocated hooks (`<script :type={Phoenix.LiveView.ColocatedHook}>`) or registered external hooks.

### Testing
- Use `start_supervised!/1` for supervised processes in tests.
- Avoid `Process.sleep/1`; use monitor/assert patterns or `:sys.get_state/1` synchronization.
- For LiveView tests, use `Phoenix.LiveViewTest` helpers (`element/2`, `has_element?/2`, `render_submit/2`, `render_change/2`) and stable DOM IDs.
- Do not assert raw full HTML when selector-based assertions are possible.

## Execution Checklist Per Story
- Story card read and understood.
- Dependencies satisfied.
- Implementation complete for acceptance criteria.
- Tests added/updated.
- `mix precommit` passes.
- One commit with story ID.
- Commit pushed.

## Useful Commands
```bash
# list stories
rg -n "^### ST-" specs/stories/[0-9][0-9]_*.md

# verify count (should be 106)
rg -n "^### ST-" specs/stories/[0-9][0-9]_*.md | wc -l

# run quality gate
mix precommit
```

## Dependency Usage Rules
When touching these packages, consult usage rules first:
- `deps/req_llm/usage-rules.md`
- `deps/jido_action/usage-rules.md`
- `deps/jido_ai/usage-rules.md`
- `deps/jido/usage-rules.md`
- `deps/ash/usage-rules.md`
- `deps/ash_postgres/usage-rules.md`
- `deps/ash_json_api/usage-rules.md`
- `deps/ash_authentication/usage-rules.md`
- `deps/ash_phoenix/usage-rules.md`
- `deps/ash_typescript/usage-rules.md`
- `deps/phoenix/usage-rules/`
