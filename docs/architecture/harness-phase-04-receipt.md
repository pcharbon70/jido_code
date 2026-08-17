# Harness Phase 4 Production Sandbox And Brokers Receipt

## Status

This receipt is being assembled with the Harness Phase 4 implementation. The
current candidate is merge-pending; HG4 remains blocked until every section is
complete, the isolation, credential, egress, hostile-repository, exhaustion,
and full regression matrices pass, clean-checkout CI passes, and the pull
request merges. Phase 5 is not authorized from this document yet.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged HG3 closure | `2b7d5478dcc39df14e39ff3cede400c8f98fd1cc` |
| Accepted Phase 3 candidate | `779afa09763c3d0fb698e4d29b83d99d654fd88e` |
| Section 4.1 | This section's exact commit is recorded by Git history |
| Section 4.2 | This section's exact commit is recorded by Git history |
| Section 4.3 | This section's exact commit is recorded by Git history |
| Section 4.4 | This section's exact commit is recorded by Git history |
| Merged candidate | Merge-pending; full merge-commit SHA must be pinned after clean-checkout CI and merge |

## Tiered Production Sandbox

The workload table is closed: read-only analysis uses a restricted BEAM
worker; non-executing transformation uses a gVisor-style container; builds,
tests, hooks, compilers, and native tools use a Firecracker-style microVM; and
unknown high-risk work uses a dedicated secret-free microVM host. An unknown
workload cannot select a tier. `MemorySandbox` remains a test implementation and
cannot satisfy the production attestation port.

| Tier | Technology | Pinned image digest |
| --- | --- | --- |
| `restricted_beam` | restricted BEAM worker | `sha256:2d98580af76e3bea20cae762b5b1f938db7c4b44f371bbf24f3b18989bb34ac4` |
| `container_sandbox` | gVisor-style container | `sha256:22e9d5f74bfef1c7365405fd077371107a48218dbe9b7a8ba45c902f0ad7d434` |
| `micro_vm` | Firecracker-style microVM | `sha256:785f0a40904108fb7f2b90a760d4d628d9c9d9d7d2c4d0743b4ba005af31c35e` |
| `dedicated_host` | dedicated microVM host | `sha256:49f5e81b78a95905ee7ddb8c16c506a71f34cc328fb24b2ee37ffb718ed6eaf0` |

Every accepted adapter attests the exact tier profile and image/tool digests.
Profiles require an ephemeral unprivileged environment, read-only root image,
copy-on-write workspace, no host filesystem, Docker socket, devices, ambient
credentials, or Linux capabilities, `no_new_privs`, a pinned syscall policy,
network deny, and only explicit workspace/artifact mounts. CPU, memory,
process, disk, output, and wall-time ceilings are positive and a request must
fit within its selected tier before provision.

The supervisor binds one attempt to one attested adapter, rejects relaxed or
incomplete registries, and destroys the environment only after bounded
collection and artifact capture. Small public/internal text uses the accepted
RDF literal artifact contract. Large, binary, or restricted output requires an
explicit provider-owned immutable HTTPS URI with digest, media type, byte
count, and accepted retention deadline; no undeclared product blob store or
fallback exists.

Provision events carry a deterministic `SandboxInstance` identity plus image,
profile, and limits digests. Execution finalization turns that bounded
observation into the existing `SandboxInstance` graph shape and sandbox
activity provenance without recording provider handles or local paths.

## Credential Broker

Credential release is serialized through a broker that rechecks the live
actor and delegation, repository and provider, active lease and fence,
attempt, invocation, profile and credential revisions, revocation generation,
and expiry at its linearization point. A request must match the policy's exact
operation and audience and can request only a non-empty subset of its scopes.
The resulting permit binds those facts, the trusted connector identity, and
the credential class without containing credential bytes or the vault key.

Only provider-native restrictions, proven token exchange, or an attaching
proxy may claim normal credential attenuation. A managed delegated CLI must
use the broker helper and is serialized by the broker so refresh ownership and
checkout cannot race. A developer-local CLI reference requires explicit
consent, sends only the reference IRI to an existing CLI session, never checks
out bytes, and cannot make a managed-fleet claim.

Material moves directly from the vault/helper callback into a digest-pinned,
trusted direct-delivery connector callback within the broker process. The
caller receives only a bounded safe result, the opaque permit, and the
restrictions actually enforced. Single-use permits are consumed before
checkout and remain consumed on downstream ambiguity. Repository payloads and
connector results are bounded and rejected if they contain credential-shaped
keys or secret material. The abstract ports define this trust boundary; real
vault and provider connectors remain deployment integrations and must retain
equivalent process and OS isolation.

## Egress Broker

Network remains disabled in every sandbox profile. Required traffic passes
through a serialized broker with an exact, revisioned policy bound to the
attempt, invocation, active lease, and fencing token. The broker rechecks that
authority and expiry for every hop. Policies admit only explicit HTTPS host,
port, and path-prefix destinations, exact methods, closed integrity and
confidentiality classes, request and response byte ceilings, redirect limits,
and per-policy request rates. Package traffic additionally requires a
destination classified as a controlled mirror; incompatible builds receive a
stable visible denial instead of broader network access.

The broker rejects URL user information, fragments, path encoding and
traversal, non-HTTPS schemes, destination changes not separately allowlisted,
and untrusted resolver identities. Its controlled resolver must return only
public addresses: loopback, private, shared, link-local, metadata-capable,
documentation, multicast, reserved, and non-global IPv6 ranges fail closed.
The trusted transport receives the selected IP separately from the TLS server
name, preventing a second hostname lookup from turning policy approval into a
DNS-rebinding bypass. Every redirect repeats destination, DNS, classification,
rate, and authority checks.

An allow or deny decision is written through a required audit port before any
transport call. Audit observations contain a destination digest and bounded
classification and byte metadata, never the URL query or body. Audit failure
is fail-closed. The response port is byte-capped and may return only bounded
safe metadata; bodies and headers do not cross back into the general harness
result. Real DNS, audit, and transport adapters remain deployment integrations
and must preserve IP-pinned TLS and streaming response limits.

## Hostile Repository And Exhaustion Hardening

The closed tier table treats package and Git hooks, workflows, build scripts,
and generated binaries as microVM workloads. A session records its authorized
workload, and every command must repeat that exact class and select a
server-approved command name. The hostile matrix attempts every such workload
through the restricted BEAM, gVisor, and dedicated-host sessions and proves
the supervisor rejects the downgrade, cancels the attempt, destroys the
environment, and removes the session. The matching microVM executions retain
all no-network, no-host, no-credential, unprivileged profile controls.

Attested execution observations now carry a closed six-field usage record.
The supervisor checks CPU time, peak memory, process count, disk, output, and
wall time against the request ceilings. Across every tier, each over-limit
case terminates and destroys its session while the supervisor continues to
admit a later valid attempt. Missing, extra, negative, or non-integer usage is
treated as a corrupt adapter boundary. Collection byte counts, artifact count,
and aggregate candidate bytes are also bounded before capture; any failure
still proceeds to destruction.

Hostile broker probes cover SSRF, link-local metadata access, redirect DNS
rebinding, and credential canaries. The credential broker rejects canary
material in connector payloads before vault checkout, while restricted data
cannot enter an egress transport. A stateful adapter fixture proves markers
exist only within one attempt and are removed by destroy before a subsequent
attempt is provisioned. The suite validates the supervisor contracts and
adapters' required observations; production isolation still depends on the
deployed adapters enforcing their attested kernel or hypervisor limits.

## Verification Record

| Command or gate | Result |
| --- | --- |
| `phase_h04_sandbox_tiers_test.exs` | 8 tests, 0 failures |
| Affected Phase 8 sandbox and provenance suites | 6 tests, 0 failures |
| `phase_h04_credential_broker_test.exs` | 7 tests, 0 failures |
| `phase_h04_egress_broker_test.exs` | 10 tests, 0 failures |
| `phase_h04_hostile_hardening_test.exs` | 6 tests, 0 failures; 24 tier-by-limit exhaustion cases plus hostile matrices |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |

## Gate HG4

HG4 is merge-pending and remains blocked. It reopens—or remains blocked—while
any workload can execute outside a tier, any credential can reach untrusted
code, or any egress can bypass the broker. These reopening conditions remain
in force regardless of checklist state.
