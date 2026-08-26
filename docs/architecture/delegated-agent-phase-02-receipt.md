# Delegated Coding Agent Phase 2 Protected Runtime Receipt

## Status

This merge-pending receipt records the Phase 2 implementation candidate built
from the accepted Phase 1 closure baseline
`79d147234b3c09d57faf75d8cc524b3aec5eb04a`. DCG2 remains open until the
implementation pull request passes clean-checkout CI, merges, and a closure
change pins the full merge-commit SHA and merge date.

The candidate defines one disabled exact Codex runtime, resolves its reviewed
binary without fallback, launches it through the pinned JidoHarness Process
API with context on closed stdin, normalizes a closed JSONL protocol, and
supports one controller-reconstructed follow-up under the same fenced
authority and total budget.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted Phase 1 closure baseline | `79d147234b3c09d57faf75d8cc524b3aec5eb04a` |
| Section 2.1 | `8c75eca` - exact Codex release, profile, and resolver |
| Section 2.2 | `3dbae8b` - protected JidoHarness Codex runner |
| Section 2.3 | `f819d44` - bounded turns, interaction, and cancellation |
| Section 2.4 | Merge-pending implementation PR head; exact commit is recorded by Git history |
| Merged candidate | **Pending clean-checkout CI and merge** |

## Runtime And Contract Pins

| Contract | Candidate value |
| --- | --- |
| JidoHarness revision | `e41fc1651282469f2db4219a48d9f7feef1b0dbc` |
| JidoHarness source archive SHA-256 | `fbe4d49edf2e5ae7843231e45c47158a15fdcdbc494b40a3d766967c1b81f8b3` |
| Codex CLI | `0.144.6` |
| Codex executable SHA-256 | `a31ae9450a26216eb1e7c53102fd42123dd675974310b0e2ca3aa4cb622a2c15` |
| Codex model | `gpt-5.3-codex` |
| Adapter release digest | `965a8af8be140834822b56737ae6d1ce4e0bab6e1407efcf91465e4d0888ae57` |
| Disabled profile digest | `708e1dbd3f24e3bc83e20d573e1da28feb86e005d60521fe4311900a54c9be5d` |
| Output-schema digest | `551d30cde5645d4dc687d1027fa2fa6cb29ed6e6288ca5a939efcb1f177fbb0d` |
| Runtime release source SHA-256 | `31efae44d7c2ce1f25f88ff4daaa6dbc45c7ee76f540520d6362c80fcb92ee03` |
| Runtime registry source SHA-256 | `229549526d6df47ee7d0be597d0091f71527500e89a52c0d58b8ec941c212066` |
| Executable registry source SHA-256 | `b4081172d5b4748074589ca83988097ce903bb157adcbdd3ce6e6017ff62123c` |
| Protected runner source SHA-256 | `a072b36e674bee6a3e6a11f8a184b540169cde71e71b844e73f09ff8f5f4d39c` |
| Event mapper source SHA-256 | `7be392cdb39d5ff1a1b7648d130abb5a1006569863e0fbbf29b6a12c2ff71aa1` |
| Turn controller source SHA-256 | `d2a0a1065b0210b7214c4b5930d9d03552f4ba7b4ad096139660313932a2958a` |
| Session protocol | `controller_reconstructed_turns`, `run_count=2`, `session_turns=2` |
| Event protocol | Closed Codex JSONL, maximum 100 ordered unique events of 65,536 bytes each |

Managed-coding release `8.0.0` carries these delegated runtime fields while
retaining exact historical interpretation of the accepted `7.0.0` manifest
and digest
`64b43c9786eb9c6d59de817aaa41f0efd287a0a7d08d84357bc604dc6f36e464`.

## Protected Launch Evidence

- The only accepted argv family is `codex exec --json --ephemeral
  --ignore-user-config --ignore-rules --strict-config --model gpt-5.3-codex
  --sandbox workspace-write --output-schema <controller-file> -`.
- The bounded compiled context enters the process only through stdin, followed
  by input closure. Prompt, memory, repository, and credential canaries are
  absent from argv, replacement environment, metadata, receipts, retained
  diagnostics, Linux process command lines, environments, names, and status.
- Runtime and executable resolution accepts only reviewed opaque keys. It
  verifies canonical root, regular non-symlink type, owner, mode, bounded size,
  exact executable digest, and exact version before dispatch.
- Unknown launch fields fail closed. Built-in adapter use, arbitrary argv,
  provider resume, user/project configuration, additional directories, MCP,
  skills, web search, unsafe sandboxing, and dangerous bypass flags are
  unreachable.
- No live provider request is part of ordinary verification. The real
  JidoHarness Process API is exercised with a controller-owned non-provider
  fixture to prove stdin transport, redacted process surfaces, timeouts, and
  process-group containment.

## Event, Interaction, And Cancellation Evidence

- Only `thread.started`, `turn.started`, `item.started`, `item.updated`,
  `item.completed`, `turn.completed`, and `error` JSONL records are accepted.
  Malformed, partial, oversized, unknown, secret-bearing, duplicate,
  out-of-order, and repeated-final input fails closed.
- Final output has exactly one controller-owned classification of `candidate`,
  `clarification`, `checkpoint`, or `failure` plus a bounded summary. File and
  check claims remain observations without candidate or verification
  authority.
- Clarification and checkpoint may produce one actor-authenticated answer or
  steering manifest. The next invocation is a fresh Codex process in the same
  workspace and under the same attempt, lease, fence, profile, workspace
  identity, and total budget. Steering while running and every third turn are
  conflicts.
- Semantic cancellation commits before runtime cancellation and independent
  process-namespace termination. Cooperative, forced, stalled, timed-out, and
  resistant-descendant paths are bounded; cancelled controllers and stale
  fences reject late events, diffs, artifacts, callbacks, and results.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Phase 2 runner, turns, real-process, and cancellation matrix | 25 tests, 0 failures |
| DCG1 regression plus Phase H05 and Phase 2 conformance matrix | 61 tests, 0 failures |
| Architecture checks | Passed; zero findings |
| Dialyzer | Passed; 177 existing warnings skipped by policy, zero unignored errors |
| Repository-wide isolated `mix precommit` | Passed; 919 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| Clean-checkout CI | Pending implementation PR |

## Known Limits And Disabled Posture

- The `codex_dga1` profile remains disabled and is not managed-eligible. Phase
  2 proves runtime mechanics only; it does not authorize ordinary developer
  selection or a live provider request.
- Credentials and workspace effects remain unavailable until DCG3 and DCG4.
  Candidate ingestion, recovery, and verification remain unavailable until
  DCG5. Product enablement and qualification remain unavailable until DCG6.
- Provider sessions, detached execution, managed fleet, arbitrary repositories,
  other providers and models, publication, acceptance, and merge authority are
  outside this candidate.
- The executable registry currently pins the reviewed developer-local Linux
  x86-64 musl Codex installation. Any additional platform or installation root
  requires its own accepted descriptor and evidence.

## Gate DCG2

Status: **merge-pending**

DCG2 becomes accepted only after clean-checkout CI passes, the implementation
PR merges, and the receipt pins the exact merged candidate and date. Phase 3 is
not authorized from this merge-pending state.

DCG2 reopens regardless of checklist state if compiled context, memory,
repository material, or credentials enter argv, environment, process titles,
metadata, diagnostics, receipts, or durable process retention; runtime,
adapter, executable, model, sandbox, flags, endpoints, provider sessions,
configuration, skills, MCP, web search, or additional directories can be
selected by graph data, caller input, repository content, environment values,
or model output; exact resolution falls back or an unverified, changed,
symlinked, writable, wrong-owner, out-of-root, wrong-version, or wrong-digest
executable can start; the built-in Codex adapter or unsafe sandbox becomes
reachable; JSONL bounds, ordering, uniqueness, secret scanning, closed event
types, or final-output schema fail open; CLI file or check claims gain
candidate, verification, publication, acceptance, or merge authority; a
follow-up reuses provider-session state, exceeds two outer invocations, widens
attempt, lease, fence, profile, workspace, or total budgets, or accepts
steering while running; cancellation occurs before semantic commitment, fails
to terminate the independent process namespace and resistant descendants
within bounds, or permits a late event or result to enter an authoritative
sink; the disabled profile becomes selectable before DCG3-DCG6 close; any
runtime or governing contract pin changes without reevaluation; any prior
semantic, harness, memory, managed-coding, or DCG1 gate reopens; or architecture
checks, Dialyzer, precommit, or clean-checkout CI fails at the exact merged
candidate.
