# Protected Codex Delegated Runtime

## Status And Scope

This document records the Phase 2 protected launch contract for the disabled
DGA1 Codex profile. It implements DCG2 mechanics without authorizing developer
selection, credentials, workspace effects, candidate acceptance, publication,
or merge.

## Exact Runtime Tuple

| Dimension | Value |
| --- | --- |
| Runtime class | `delegated_cli` |
| Adapter and executable key | `codex_cli` |
| Runtime adapter | `JidoCode.Runtime.JidoHarnessAdapter` |
| Protected runner | `JidoCode.Runtime.JidoHarness.CodexProcessRunner` |
| JidoHarness revision | `e41fc1651282469f2db4219a48d9f7feef1b0dbc` |
| JidoHarness archive SHA-256 | `fbe4d49edf2e5ae7843231e45c47158a15fdcdbc494b40a3d766967c1b81f8b3` |
| Codex CLI and SHA-256 | `0.144.6`, `a31ae9450a26216eb1e7c53102fd42123dd675974310b0e2ca3aa4cb622a2c15` |
| Model | `gpt-5.3-codex` |
| Event protocol | bounded Codex JSONL |
| Final output | controller-owned closed JSON Schema |

The application registry maps this tuple to compiled modules and a canonical
installation path. Before dispatch it verifies a regular non-symlink file,
approved root, owner, non-writable mode, bounded size, digest, and exact
`codex-cli 0.144.6` version response. Every lifecycle operation resolves the
tuple again and then passes through the existing execution-runtime authority
check.

## Protected Launch

The runner constructs only this argument family:

~~~text
codex exec --json --ephemeral --ignore-user-config --ignore-rules
  --strict-config --model gpt-5.3-codex --sandbox workspace-write
  --output-schema <controller-owned-0600-file> -
~~~

The bounded compiled manifest is written to stdin and the input stream is
closed. Prompt bytes are absent from argv, environment values, launch
metadata, normalized diagnostics, runtime receipts, and retained process
records. Environment replacement accepts only the closed host-owned names.
Caller flags, endpoints, additional directories, profiles, configuration,
MCP, skills, web search, images, unrestricted sandboxing, and dangerous bypass
options are unreachable. The upstream JidoHarness Codex adapter remains
blocked.

## Event And Result Adoption

Only the pinned event types are decoded. Each JSONL record is size bounded,
secret scanned, correlated by a monotonic JidoHarness sequence, reduced to a
payload digest, and mapped to an existing normalized observation class.
Malformed, partial, oversized, unknown, secret-bearing, duplicate, or
out-of-order input fails closed.

The controller-owned final schema permits exactly `candidate`,
`clarification`, `checkpoint`, or `failure` plus a bounded summary. Only the
classification and summary digest are retained. CLI file changes, check
claims, internal tools, hidden reasoning, and provider session state remain
partial observations and cannot become candidate or verification authority.

## Controller-Reconstructed Turns

The DGA1 session protocol is `controller_reconstructed_turns`. It permits
exactly two outer invocations: one initial invocation and, only after an
accepted clarification or checkpoint boundary, one actor-authenticated answer
or steering invocation. The follow-up is a fresh Codex process in the same
fenced workspace; provider-session resume and live stdin steering are not
session authority.

Every invocation carries the same attempt, lease, fencing token, runtime
profile, workspace identity, and total budget. The controller rejects steering
while a process is running, rejects widened or stale actor input, and fails a
second interactive result as turn exhaustion. Cancellation commits the
semantic transition before invoking runtime cancellation and independent
process-namespace termination. Once cancelled, all late events and results are
conflicts.

## Disabled Posture

The profile remains graph-disabled through DCG3-DCG6. Phase 2 runtime code has
no graph handle, reusable credential, publication credential, acceptance
authority, or merge authority. Later phases must prove local credential,
workspace, candidate, recovery, verification, product, and qualification
gates before selection is enabled.
