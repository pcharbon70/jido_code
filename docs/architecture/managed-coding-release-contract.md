# Managed Coding Runtime Release Contract

Status: final candidate, merge-pending  
Contract version: `7.0.0`

## Supported Product Boundary

The supported production runtime is the exact Phase 6 `single_agent` profile
with digest
`d2042eb2dfd52d1572cff7c7621042f37a524e113b3f266e0a2161ac8bec088d`.
`TripleStore`, reached only through accepted Knowledge commands and queries, is
the sole durable authority. Agent, strategy, Pod, registry, mailbox, ETS,
provider, sandbox, workspace, stream, scheduler, and verifier processes remain
disposable.

```text
product API: JidoCode.Factory.ManagedCoding
  -> graph admission, policy, lease, profile, capability, and fence
    -> one Jido.Agent through the product-owned runtime port
      -> context/model/tool/memory effects through existing Factory gateways
        -> content-addressed candidate
          -> independent fresh-checkout verification
            -> governed disposition
              -> separate human-authorized publication and merge
```

The public workflow is admit, start, steer, cancel, status, await, handoff,
independent verification, human decision, and human merge. Runtime handles,
graph handles, credentials, provider sessions, mutable transcripts, and process
state are never public contract values.

## Component And Decision Map

| Component | Owner | Release status |
| --- | --- | --- |
| Durable task/attempt/effect/candidate/evidence/decision state | Knowledge graph | Accepted, exclusive authority |
| Admission, budgets, gateways, candidate closure, governance | Factory | Accepted |
| One managed `Jido.Agent` and isolated workspaces | Runtime | Accepted, disposable |
| Fresh-checkout verifier | Independent verifier port | Accepted, no decision authority |
| Draft publication | Human-authorized publication boundary | Restricted to the Phase 6 pilot envelope |
| Investigator/coder/reviewer Pod | Evaluation fixture | Rejected for production; no default managers |
| AgentOS services or persistence | None | Rejected; dependency and adapter absent |
| Automatic approval/publication/merge | None | Rejected and unavailable |

The specialist decision is recorded in
[`managed-coding-specialist-evaluation.md`](./managed-coding-specialist-evaluation.md).
The AgentOS decision is recorded in
[`decisions/managed-coding-agent-os.md`](./decisions/managed-coding-agent-os.md).

## Consolidated Operating Material

- Compatibility: `jido-2.3.2-managed-coding-compatibility.md`
- Authority and threats: `managed-coding-runtime-contract.md` and the Phase 1 receipt
- Production profile and change control: Phase 6 receipt
- Evaluation, shadow, pilot, rollout, disable, incident, and rollback controls:
  Phase 6 receipt and `../operations/managed-coding-rollout.md`
- Recovery, cancellation, ambiguity, credentials, isolation, and capacity:
  Phase 5 receipt and `../operations/managed-coding-runtime.md`
- Candidate verification, decision, and publication separation: Phase 4 receipt

No migration, dependency, feature flag, public API, telemetry label, dashboard,
or UI surface selects a specialist or AgentOS profile. The default Runtime
supervisor starts neither Pod nor specialist InstanceManagers. Evaluation code
is reachable only through an explicitly supplied internal runtime port in test
or future qualification code; it is not registered by the product facade.

## Post-Plan Operations

- Availability target: 99% for admitted supported-profile attempts.
- Unsafe-effect and merge-authority violation budgets: zero.
- Review the signed profile, capacity envelope, evaluation drift, and rollout
  evidence at least every 30 days.
- Reevaluate the threat model, credentials, dependencies, data handling, and
  incident ownership at least every 90 days and after every material incident.
- Any Jido, model, prompt, tool, context, sandbox, check, credential, memory,
  verifier, policy, corpus, topology, or environment change creates a new
  signed profile and requires the applicable compatibility and qualification
  gates before rollout.
- Future automation must preserve exact graph authority, full effect
  accounting, independent verification, explicit publication authorization,
  repository protections, and human merge authority.

Every MCG1-MCG7 reopening condition remains effective after plan closure.
Checkboxes and elapsed review time never override a failed invariant.
