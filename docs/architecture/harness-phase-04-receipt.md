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

## Verification Record

| Command or gate | Result |
| --- | --- |
| `phase_h04_sandbox_tiers_test.exs` | 8 tests, 0 failures |
| Affected Phase 8 sandbox and provenance suites | 6 tests, 0 failures |
| `mix compile --warnings-as-errors` | Pass |
| `mix architecture.check` | Pass |

## Gate HG4

HG4 is merge-pending and remains blocked. It reopens—or remains blocked—while
any workload can execute outside a tier, any credential can reach untrusted
code, or any egress can bypass the broker. These reopening conditions remain
in force regardless of checklist state.
