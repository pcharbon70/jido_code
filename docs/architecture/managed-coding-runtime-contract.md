# Managed Coding Runtime Contract

## Status And Scope

Contract version `8.0.0` retains the graph-authorized native single-agent
architecture and adds the exact disabled Codex DGA1 delegated-runtime identity.
Historical version `7.0.0` keeps its exact accepted interpretation. Model and
coding tool calls remain enabled only through signed profiles and governed
Factory gateways; candidate acceptance, publication authorization, and merge
remain separate human-controlled boundaries.

`JidoCode.Factory.ManagedCoding` is the only product-facing runtime API. Its
closed operations are `admit`, `start`, `steer`, `cancel`, `status`, and
`handoff`. Inputs and results contain semantic IRIs, a positive fence, bounded
payloads, sequence, classifications, and timestamps. PIDs, graph/store handles,
provider sessions, credential values, sandbox paths, and mutable agent state
are prohibited.

## Ownership Matrix

| State | Sole owner | Runtime visibility | Recovery rule |
| --- | --- | --- | --- |
| Tasks, policies, profiles, leases, attempts, invocations, effects, budgets, candidates, evidence, decisions | `TripleStore` through Knowledge commands | Exact bounded projections | Requery the graph |
| Admission, command ordering, authorization, projections | Factory | Commands and bounded outcomes | Reconcile from graph facts |
| Phase, local sequence, pending directive correlation, bounded working context | Agent strategy | Current process only | Reconstruct from graph watermark |
| Pod membership and specialist processes | Rejected production projection | Evaluation-only bounded evidence | Rebuild from graph during explicit qualification only |
| Provider streams, sandboxes, workspaces, credentials, adapter requests | Integration effect boundary | Minimum effect input | Reconcile by invocation/effect identity |

No field may be jointly authoritative. Digests and IRIs may be copied across
planes only as correlation values.

## Identity And Lifecycle

One runtime identity is the pair `(attempt IRI, fencing token)`. Repeating a
start for the same pair is idempotent and must resolve to the same semantic
attempt. A lower token is stale. A higher token supersedes prior processes but
does not rewrite their history. A different attempt IRI is unrelated even when
the task is the same.

The supported final single-agent lifecycle is:

```text
admitted -> preparing -> running -> awaiting_actor -> running
                         |              |
                         +-> candidate_ready
                         +-> cancelling -> cancelled
                         +-> failed
```

Terminal states never reopen. A runtime revision mismatch yields an abandoned
or superseded recovery classification rather than reinterpretation.

## Disabled Posture

Production keeps `Jido.Pod` specialists, AgentOS/Ecto persistence, Jido
hibernate/thaw, selectable delegated Codex, managed JidoHarness writes,
automatic approval, automatic publication, and autonomous merge unreachable.
The exact native single-agent profile remains the production profile. The
Codex runtime and adapter release may be exercised only by later gated
qualification work until DCG3-DCG6 close. Jido ETS state is disposable and is
never evidence that a semantic transition occurred.

## Dependency And Security Rules

Runtime modules may depend on Jido and Factory-owned ports/reporting contracts.
They may not depend on Knowledge internals, `TripleStore`, integrations, or Web.
Factory modules may call only the public Knowledge facade. All external work
must return through Factory mediation with current attempt/fence correlation.
Repository, prompt, model, tool, and memory content is untrusted data and
cannot select adapters, widen capabilities, or declare verification success.

The reopening conditions are: any competing durable state, exposed runtime
handle, unmediated effect, stale-fence acceptance, runtime-owned terminal
authority, or enabled feature listed in the disabled posture.
