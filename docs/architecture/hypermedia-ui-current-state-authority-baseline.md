# Hypermedia UI Current-State Authority Baseline

## Status And Purpose

This document records the immutable starting candidate for Secure Hypermedia
Control Plane UI Milestone A Phase 1. It is evidence for HUI-A1, not acceptance
of the proposed hypermedia ADRs or target runtime. Existing accepted decisions,
contracts, receipts, and release restrictions remain authoritative.

The machine-readable companion is
[`priv/architecture/hypermedia_ui/phase_a1_authority_baseline.json`](../../priv/architecture/hypermedia_ui/phase_a1_authority_baseline.json).
It owns the exact hashes, path sets, status classes, owners, supersession rules,
reopening rules, and explicit exceptions summarized here.

## Candidate Provenance

| Item | Pinned value |
|---|---|
| Starting branch | `main` |
| Starting commit | `7c91977921c7b170d6def6bd390af93ddd4af09e` |
| Merge subject | `Merge pull request #100 from pcharbon70/docs/secure-hypermedia-ui-architecture-plan` |
| First parent | `2f287a423acb1cc7265b4ad75eab7a1842165c1b` |
| Topic parent | `7b81c05ec4a995d87d3f0a8b4947907105f0c05b` |
| Recorded | 2026-09-02 |

The manifest records ten first-parent commits so later inventory work can
distinguish the repository-wiki and delegated-agent accepted baselines from
PRs 97 through 100, which established current architecture and the proposed
hypermedia program.

## Reproducible Content Manifests

The baseline uses Git object identities rather than filesystem timestamps.
Run these commands from a clean checkout to reproduce the path and content
manifests:

```sh
git ls-tree -r 7c91977921c7b170d6def6bd390af93ddd4af09e -- \
  AGENTS.md README.md docs/adr docs/architecture docs/contributing \
  docs/operations docs/planning docs/research | sha256sum

git ls-tree -r 7c91977921c7b170d6def6bd390af93ddd4af09e -- \
  .tool-versions assets config lib mix.exs mix.lock package-lock.json \
  package.json rust-toolchain.toml | sha256sum
```

| Manifest | Entries | SHA-256 |
|---|---:|---|
| Governing documents | 245 | `4a538d6a02359fd536f7e4db7dfd97920ccdfb316e6346222b7b5a7f21038c44` |
| Implementation and build definition | 761 | `ce73aad3e129592cd279148a70683bc52a27bd93395fc67d28231660c1b2909a` |

`mix.lock`, `package-lock.json`, the toolchain declarations, production
configuration, and client/SSR/CSS entry points also have individual SHA-256
values in the machine manifest. Generated Vite and Phoenix digest manifests
are intentionally not tracked; the accepted asset build regenerates them from
the pinned lockfiles and entry points.

## Toolchain And Production Configuration

The starting candidate declares Erlang 28.3.1, Elixir 1.19.5 for OTP 28,
Rust/Cargo 1.92.0, and Node.js 24.3.0. The recorded build environment also has
npm 11.4.2, Git 2.49.0, CMake 3.28.3, `pkg-config` 1.8.1, and GCC 13.3 on an
Ubuntu 24.04 x86-64 base.

Production requires `JIDO_CODE_OPERATOR_TOKEN` and `SECRET_KEY_BASE`.
`JIDO_CODE_STORE_ROOT` and `JIDO_CODE_BACKUP_ROOT` must be supplied together
when overriding the defaults. The enabled store is quad schema version 1,
synchronous durability, a 15-second open timeout, and defaults to
`/var/lib/jido_code/knowledge` plus `/var/lib/jido_code/backups`.

The browser runtime at this baseline is LiveView with bounded LiveVue islands,
SaladUI hooks, Vite client and SSR builds, and Phoenix static digesting. The
current authentication exception is one configured operator projected to the
default factory scope. Nothing in HUI-A1 widens that authority.

## Authority Order And Document Status

When two sources disagree, use this order:

1. accepted ADRs;
2. accepted architecture contracts and receipts pinned to merged candidates;
3. executable release manifests and invariant tests;
4. current architecture and operations evidence;
5. implementation plans; and
6. research.

The exact document classes and paths are in the machine manifest. Their status
at the starting candidate is:

| Class | Status | Owner | Supersession and reopening rule |
|---|---|---|---|
| ADRs 0001-0007 | Accepted | Owners named by each ADR | Only a named accepted ADR may supersede them; any invariant failure reopens its earliest gate |
| ADRs 0008-0011 | Proposed | Milestone A decision owners | Nonbinding until Milestone A accepts or narrows them |
| 42 phase receipts | Accepted at merged candidates | Respective plan-family owners | Later receipts may advance contracts but never erase reopening conditions |
| Twelve hypermedia specifications | Proposed | Milestone A contract owners | Every affected accepted clause requires an explicit disposition |
| Remaining architecture documents | Current authority or evidence according to their receipt/ADR chain | Named module or plane owners | Accepted ADRs and receipts win over stale narrative |
| Plans | Execution structure | Declared repository and phase owners | Checkboxes do not override accepted authority or grant completion |
| Research | Nonbinding analysis | Research authors/reviewers | Requires an accepted ADR and gated implementation to become binding |
| Operations and contributor rules | Current operational/contributor guidance | Operations, security, release, and repository maintainers | Must change with accepted contracts and may not weaken a gate |

## Explicit Starting Exceptions

- The product authenticates one configured operator and one default factory
  scope. Named humans and multi-human separation of duty are proposed, not
  implemented.
- The delegated Codex profile remains disabled until DCG6 is accepted.
- The graph substrate and component contracts are extensive, but the default
  application does not yet compose every scheduler, managed-coding, sandbox,
  credential, verifier, publication, and observation adapter end to end.
- The hypermedia UI program is proposed and grants no runtime or release
  credit before HUI1.

These are owned limitations, not permission to add fallback state or advertise
unavailable capability as production-ready.

## Change Procedure Before HUI1

This starting record is immutable. A fact that changes during Milestone A is
recorded as a delta with its path, old value, new value, commit, owner, and
disposition in the runtime inventory and phase receipt. A corrected baseline
must advance the manifest schema and retain both hashes. Missing paths,
ambiguous document status, unowned exceptions, or a non-reproducible digest
keep HUI-A1 merge-pending.

