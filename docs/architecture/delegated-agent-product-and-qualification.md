# Delegated Coding Agent Product And Qualification Specification

- Status: Approved and normative under accepted ADRs 0003 and 0004
- Specification version: `0.1.0`
- Owners: JidoCode product, evaluation, security, and operations maintainers
- Profile contract: [Delegated agent profile catalog](./delegated-agent-profile-catalog.md)
- Runtime contract: [Delegated agent runtime protocol](./delegated-agent-runtime-protocol.md)

## Purpose

This specification defines the developer-facing workflow and evidence gates
for turning a supported JidoHarness CLI into a usable JidoCode coding agent. It
separates a developer-local preview milestone from managed-fleet production so
local subscription utility is not blocked on fleet credentials, while neither
mode overclaims its security or operational posture.

## Presentation Runtime And Supersession

The browser workflow is presentation-runtime neutral at its durable boundary.
For the HUI target, explicit controllers and HEEx render reviewed projections;
bounded Datastar requests and the application-owned Dstar/SSE coordinator may
refresh them. Every action still enters the same semantic gateway and every
result still derives from a receipt plus a fresh authorized projection.
Signals, DOM, streams, tabs, browser connection state, and server processes
cannot start a runtime, select an adapter, widen scope, or prove progress.
Current compatibility routes retain their accepted evidence until their
Milestone H consumer and rollback gates close.

## Product Workflow

The supported end-to-end workflow is:

```text
enrolled repository and eligible task
  -> scope-filtered agent catalog
    -> explicit agent/profile selection
      -> readiness and consent/billing disclosure
        -> graph admission and fenced runtime launch
          -> progress, clarification, steering, or cancellation
            -> controller-captured candidate
              -> independent verification and governed decision
                -> human-authorized draft publication
                  -> human review and merge
```

The browser, API, and CLI surfaces use the same semantic commands and reviewed
queries. No surface directly starts a process, selects an adapter module,
constructs executable arguments, accesses credentials, or writes raw RDF.

## Agent Catalog Surface

The catalog MUST:

- show native and delegated coding offerings together while clearly labeling
  runtime class;
- filter at query time by current actor, tenant, repository, task class,
  language, capability, rollout, and time;
- show provider, deployment class, billing classification, capability summary,
  readiness age, rollout stage, and material limitations;
- distinguish unavailable, disabled, revoked, expired, evaluation, shadow,
  pilot, and production states;
- require explicit selection when more than one profile is eligible; and
- expose only an opaque selection reference resolved server-side to the exact
  profile IRI and digest.

The catalog MUST NOT imply that a CLI display name, installation, login, or
readiness signal makes the profile authorized.

## Readiness

Readiness is a bounded, expiring observation, not authority. It is evaluated
for the exact profile and includes:

- accepted adapter and JidoHarness revision present;
- compatible CLI version installed;
- executable registry resolution;
- sandbox image and worker readiness;
- network/broker readiness;
- credential-reference availability and current revocation generation;
- provider authentication signal without claiming an unproven actor identity;
- candidate-capture and verifier availability; and
- optional consent-gated live smoke result.

Discovery performs no billable prompt-bearing request. A live smoke requires
authenticated actor consent, profile identity, expiry, and billing
acknowledgement. Readiness expires on time or immediately after any material
profile, adapter, CLI, credential, sandbox, network, verifier, or policy change.

## Task Submission

A task submission contains semantic intent, repository/snapshot selection,
task class, acceptance requirements, selected opaque agent offering, actor
identity, and an idempotency key. It contains no provider credential,
executable, module, raw sandbox configuration, or arbitrary shell command.

Admission returns a bounded outcome describing admitted, duplicate, stale,
unauthorized, incompatible, unavailable, or rejected state. Process creation
cannot occur before the graph commits the attempt, exact profile digest, lease,
fence, context/delegated-input manifest, and invocation-before-effect record.

Developer-local submission additionally requires foreground explicit consent
and cannot be silently scheduled as background fleet work. Managed-fleet
submission requires a currently authorized rollout cohort and capacity
envelope.

## Attempt Surface

The attempt surface MUST provide stable element/API identities for:

- runtime class, agent/profile, provider, deployment, billing, and readiness;
- attempt lifecycle, wait reason, fence-safe sequence, and bounded budgets;
- normalized interactions and clarification requests;
- runtime and provider observations labeled by completeness;
- workspace effects and registered checks;
- candidate identity, changed-file summary, secret scan, and digest;
- independent verification, evidence sufficiency, and disposition;
- steering, answer, cancellation, retry/recovery, and refresh controls; and
- publication handoff and resulting draft pull-request reference when
  separately authorized.

The surface must clearly distinguish CLI-reported observations from
controller-observed effects and independent verifier evidence. Raw provider
transcripts, hidden reasoning, credentials, graph IRIs, sandbox paths, process
identifiers, and unbounded output are not displayed.

## Controls

Every control is idempotent and bound to the current attempt, actor, state,
sequence, lease, fence, and profile digest.

- `steer` sends bounded untrusted guidance without changing authority.
- `answer` responds only to the current clarification request and audience.
- `cancel` commits before runtime propagation and may require confirmation.
- `retry` is available only from an accepted recovery classification and never
  repeats an ambiguous effect generically.
- `handoff` requests candidate closure; it does not claim verification or
  acceptance.
- `authorize_draft_publication` requires an immutable candidate, accepted
  verification/decision evidence, repository policy, an authenticated human
  actor, a single-use action digest, and current provider protections.

No control changes provider, runtime class, credential mode, billing mode,
tool capability, sandbox, source base, or verifier within an attempt. Such a
change creates a new profile and attempt.

## Qualification Unit

Qualification applies to the exact tuple:

```text
provider + CLI/version + JidoHarness/adapter release
+ deployment/authentication/billing/credential class
+ tool/capability manifest + sandbox/network/workspace profile
+ task/language/repository envelope
+ candidate/verifier/policy revisions
```

Evidence does not transfer across a changed tuple. A profile digest change is
a new qualification subject.

## Rollout Stages

| Graph stage and product posture | Permitted activity | Required evidence |
| --- | --- | --- |
| `disabled` | Catalog history only | Profile parses but is not selectable |
| `evaluation` | Deterministic fixtures and isolated non-production repositories | Contract, cancellation, privacy, sandbox, candidate, and verifier matrices |
| `evaluation` / developer preview | Explicit foreground `developer_local` runs and human-reviewed candidates | Live readiness, consent/billing, real CLI task evidence, zero-tolerance safety gates |
| `shadow` | Managed execution with no authoritative external publication | Managed credential/sandbox evidence, representative private corpus, operational telemetry |
| `pilot` | Bounded cohort and human-authorized draft pull requests | Thresholds, on-call, repository allowlist, protections, incident/disable/rollback drills |
| `production` | Supported envelope under declared SLO and capacity | Sustained observation window, independent approval, current signed release contract |

Developer preview is a product label for `rolloutStage=evaluation` plus
`deploymentClass=developer_local`; it is not a new graph vocabulary value. No
profile skips stages. Developer-local evidence cannot authorize managed-fleet
operation.

## Evaluation Tracks

Each profile must have separate results for:

### Utility

- representative task completion;
- independently verified candidate correctness;
- regression and required-check pass rates;
- human acceptance, edit burden, and review time;
- clarification and abandonment rates; and
- comparison with the native single-agent baseline and an appropriate human or
  no-agent baseline.

### Security And Privacy

- prompt injection and malicious repository content;
- credential, journal, prompt, cross-actor, and host-data canaries;
- path, symlink, special-file, sandbox, egress, process, and resource attacks;
- attempted profile/tool/policy/publication escalation;
- stale-fence and late-result attacks; and
- dependency, CLI, adapter, and provider-supplied output attacks.

Unsafe effect, credential disclosure, cross-scope disclosure, publication
authority violation, protected-branch mutation, and merge-authority violation
have zero tolerance.

### Reliability And Recovery

- provider latency, throttling, outage, partial streams, and malformed events;
- CLI crash, hang, fork, orphan descendants, and non-cooperative cancellation;
- BEAM and worker restart;
- ambiguous provider and filesystem outcomes;
- candidate capture and fresh-checkout reconstruction; and
- disable, drain, rollback, and reenable drills.

### Cost And Operations

- wall time, idle time, process/memory/disk/output use;
- reported tokens and subscription/metered usage with honest enforcement class;
- capacity, queueing, cancellation reserve, and cost ceilings;
- operator intervention and incident burden; and
- provider/CLI version and readiness drift.

The evaluation program pins corpus, repositories, revisions, seeds where
applicable, trials, adjudication, thresholds, confidence analysis, failure
review, and evidence digest. Threshold values belong to the signed evaluation
profile rather than being silently embedded in product code.

## Remediation Milestones

### DGA1 — Developer-Useful Harness Agent

The immediate gap is remediated for developers only when at least one exact
delegated profile:

1. is selectable in the product as `developer_local`;
2. uses a real supported coding CLI through the protected JidoHarness process
   API;
3. has `workspace_write_registered_checks` capability inside the isolated
   worker;
4. authenticates through the accepted local-reference boundary with explicit
   consent and billing disclosure;
5. completes real repository tasks and yields controller-recomputed candidate
   artifacts;
6. passes independent fresh-checkout verification;
7. supports steering, clarification, cancellation, containment, and cleanup;
8. cannot publish or merge; and
9. passes its signed developer-preview qualification gate.

The existing Pi deny-all and read-only profiles do not satisfy DGA1.

### DGA2 — Managed Harness Agent

The production code-factory gap is remediated only when at least one exact
delegated profile additionally:

1. uses a proven workload exchange or attaching proxy;
2. runs in the deployed production sandbox with tenant isolation;
3. passes managed shadow and bounded draft-PR pilot stages;
4. meets its declared utility, security, reliability, cost, and review-burden
   thresholds over the required observation window;
5. has operational dashboards, alerts, on-call, disable, drain, incident,
   credential rotation, and rollback evidence; and
6. is named in a new signed release contract with current provider and
   repository protections.

## Initial Provider Sequencing

The approved first implementation plan selects Codex CLI for a
`developer_local`, `jido_code`-only profile based on current developer demand,
credential-isolation feasibility, JidoHarness process maturity, cancellation
support, candidate behavior, and testability. It does not enable all upstream
adapters at once.

After DGA1, additional Codex, Claude Code, Pi, Gemini CLI, OpenCode, or other
profiles repeat the same provider-specific gates. Ordering is a product
decision supported by evidence, not an architectural preference in this spec.

## Integration Acceptance

The final clean-checkout suite for any profile release MUST prove:

- catalog visibility and non-disclosure across actors, tenants, repositories,
  capabilities, lifecycle states, and expired evidence;
- exact selection with no runtime/provider/authentication/billing fallback;
- complete submission-to-admission-to-runtime-to-candidate flow;
- real local filesystem effects in an isolated disposable workspace;
- current fence enforcement before every JidoCode-controlled effect;
- independent fresh-checkout verification and decision separation;
- human-authorized draft publication separation when pilot scope includes it;
- cancellation, restart, ambiguity, resource exhaustion, and provider outage;
- credential and privacy adversarial matrices;
- backup/restore and graph-only reconstruction of durable state; and
- all prior graph, harness, memory, managed-coding, architecture, precommit,
  Dialyzer, and clean-checkout CI gates.

Acceptance evidence must pin the merged candidate, exact profile and component
digests, deployment class, enabled/disabled adapters, residual limitations,
and every earlier gate reopening condition.
