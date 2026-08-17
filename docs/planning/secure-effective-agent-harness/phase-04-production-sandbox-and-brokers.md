---
id: plan.jido_code_secure_effective_agent_harness_phase_04
parent_plan: plan.jido_code_secure_effective_agent_harness
status: planned
intent: feature
---

# Harness Phase 4 - Production Sandbox And Brokers

This phase makes repository code execution survivable: tiered production
isolation, a credential broker that never leaks material to the model or
sandbox, a default-deny egress broker, and hostile-repository hardening.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Isolate untrusted execution and remove the credential-egress combination.

  This phase ensures that even a fully compromised model cannot reach host
  filesystems, ambient credentials, or unapproved networks.

  - [x] 4.1 Section - Implement tiered sandbox supervision.

    This section matches isolation cost to provable risk with immutable
    images and bounded artifact capture.

    - [x] 4.1.1 Task {#sah-p04-sandbox-tiers} [repo: jido_code] [after: {#sah-p03-phase-receipt}] - Implement the sandbox supervisor and isolation tiers.

      This task keeps the memory sandbox for tests only and makes
      production isolation a real boundary.

      - [x] 4.1.1.1 Subtask {#sah-p04-4-1-1-1} - Implement the tier table: restricted BEAM worker for read-only analysis, strong container or gVisor-style sandbox for non-executing transformation, Firecracker-style microVM for builds, tests, hooks, compilers, and native tools, and a dedicated secret-free microVM host for unknown high-risk workloads.
      - [x] 4.1.1.2 Subtask {#sah-p04-4-1-1-2} - Enforce ephemeral unprivileged environments with read-only base images and copy-on-write workspaces, no host filesystem, Docker socket, devices, or ambient credentials, dropped capabilities, `no_new_privs`, restrictive system-call policy, and CPU, memory, process, disk, output, and wall-time limits.
      - [x] 4.1.1.3 Subtask {#sah-p04-4-1-1-3} - Keep network disabled by default, mount only explicit workspace and artifact paths, pin sandbox image and tool digests, and destroy the environment after bounded artifact capture.
      - [x] 4.1.1.4 Subtask {#sah-p04-4-1-1-4} - Capture artifacts without creating an undeclared blob store: small classified text under accepted RDF literal limits, large or binary candidates as provider-owned immutable URIs with media type, byte count, and digest, retained for the verifier and accepted retention period before destruction.
      - [x] 4.1.1.5 Subtask {#sah-p04-4-1-1-5} - Record `SandboxInstance` lifecycle observations with image, limits, and attempt identity through the execution reporting commands.

  - [x] 4.2 Section - Implement the credential broker.

    This section makes credential release a linearizable, scoped, auditable
    decision that never exposes material to untrusted code.

    - [x] 4.2.1 Task {#sah-p04-credential-broker} [repo: jido_code] [after: {#sah-p04-sandbox-tiers}] - Implement brokered credential release.

      This task separates secret material from prompts, agent state,
      worktrees, sandboxes, tool arguments, graph literals, and telemetry.

      - [x] 4.2.1.1 Subtask {#sah-p04-4-2-1-1} - Authorize release of a graph-held `CredentialReference` against actor and delegated identity, repository and provider, exact operation and audience, minimum scopes, release expiry and optional single use, attempt, lease, and fencing token, and trusted adapter identity.
      - [x] 4.2.1.2 Subtask {#sah-p04-4-2-1-2} - Record credential class and the restrictions the provider or proxy actually enforces; describe attenuation only for proven exchanges or credential-attaching proxies.
      - [x] 4.2.1.3 Subtask {#sah-p04-4-2-1-3} - Deliver material directly to the trusted connector, never to the model or a host-controlled general sandbox; recheck profile and credential revisions, owner and delegation, revocation generation, and invocation identity at the linearization point and issue one release permit.
      - [x] 4.2.1.4 Subtask {#sah-p04-4-2-1-4} - For developer-local CLI use, record only an opaque reference to the existing CLI login under explicit consent, copy no token bytes anywhere, and keep this mode ineligible for managed fleet claims.
      - [x] 4.2.1.5 Subtask {#sah-p04-4-2-1-5} - Keep managed delegated-CLI credentials in a broker or helper that repository tool descendants cannot read, copy, or invoke, with refresh ownership serialized per credential and no writable shared cache in the untrusted process tree.

  - [x] 4.3 Section - Implement the egress broker.

    This section makes network access an explicit, authenticated, bounded
    policy decision.

    - [x] 4.3.1 Task {#sah-p04-egress-broker} [repo: jido_code] [after: {#sah-p04-credential-broker}] - Implement default-deny brokered egress.

      This task removes arbitrary network reachability from injected or
      compromised workloads.

      - [x] 4.3.1.1 Subtask {#sah-p04-4-3-1-1} - Deny network access by default and require authenticated broker passage for all required traffic.
      - [x] 4.3.1.2 Subtask {#sah-p04-4-3-1-2} - Enforce destination, method, protocol, data classification, byte, redirect, and rate policy at the broker, evaluating both integrity and confidentiality axes.
      - [x] 4.3.1.3 Subtask {#sah-p04-4-3-1-3} - Block loopback, private, link-local, and cloud-metadata ranges, unsafe URL schemes, uncontrolled DNS, and arbitrary package registries; support controlled mirrors and explicitly approved destinations only.
      - [x] 4.3.1.4 Subtask {#sah-p04-4-3-1-4} - Make incompatible builds fail visibly rather than receive unrestricted egress, and record egress decisions as bounded audit observations.

  - [x] 4.4 Section - Harden against hostile repositories and exhaustion.

    This section proves the boundary against the attack classes the research
    enumerates.

    - [x] 4.4.1 Task {#sah-p04-hostile-hardening} [repo: jido_code] [after: {#sah-p04-egress-broker}] - Exercise hostile repositories and resource exhaustion.

      This task validates containment before any real delegated or
      publication workload runs.

      - [x] 4.4.1.1 Subtask {#sah-p04-4-4-1-1} - Exercise malicious package hooks, Git hooks, workflows, build scripts, and generated binaries against every isolation tier.
      - [x] 4.4.1.2 Subtask {#sah-p04-4-4-1-2} - Exercise metadata-service, SSRF, DNS-rebinding, redirect, and canary-secret exfiltration attempts against the egress broker and credential boundary.
      - [x] 4.4.1.3 Subtask {#sah-p04-4-4-1-3} - Exercise CPU, memory, process, disk, output, and time exhaustion against sandbox limits and prove supervisor stability and bounded artifact capture.
      - [x] 4.4.1.4 Subtask {#sah-p04-4-4-1-4} - Prove sandbox destruction after capture and no persistence or escape across attempts.

  - [ ] 4.5 Section - Phase 4 Integration Tests.

    This final section proves isolation, brokering, and hardening end to
    end.

    - [x] 4.5.1 Task {#sah-p04-integration} [repo: jido_code] [after: {#sah-p04-hostile-hardening}] - Execute the isolation and broker matrices.

      This task certifies the execution environment before delegated CLI
      work is authorized.

      - [x] 4.5.1.1 Subtask {#sah-p04-4-5-1-1} - Prove tier selection follows the risk table, images match pinned digests, and every limit is enforced with bounded failures.
      - [x] 4.5.1.2 Subtask {#sah-p04-4-5-1-2} - Prove credential release requires every broker condition, revoked and expired references never release, and no material appears in prompts, arguments, journals, telemetry, or the graph.
      - [x] 4.5.1.3 Subtask {#sah-p04-4-5-1-3} - Prove default-deny egress, approved-destination passage, classification-based blocking, and visible failure for incompatible builds.
      - [x] 4.5.1.4 Subtask {#sah-p04-4-5-1-4} - Rerun hostile-repository and exhaustion suites, prior phases, architecture scans, and `mix precommit`.

    - [ ] 4.5.2 Task {#sah-p04-phase-receipt} [repo: jido_code] [after: {#sah-p04-integration}] - Publish the Phase 4 sandbox-and-broker receipt.

      This task records the isolation evidence in
      `docs/architecture/harness-phase-04-receipt.md` and authorizes Phase 5
      only from the pinned merged baseline.

      - [x] 4.5.2.1 Subtask {#sah-p04-4-5-2-1} - Record tier implementations, image digests, broker policies, and the candidate commit.
      - [x] 4.5.2.2 Subtask {#sah-p04-4-5-2-2} - Attach isolation, credential, egress, and hostile-suite results with known limitations.
      - [x] 4.5.2.3 Subtask {#sah-p04-4-5-2-3} - Keep HG4 blocked while any workload can execute outside a tier, any credential can reach untrusted code, or any egress can bypass the broker.
      - [ ] 4.5.2.4 Subtask {#sah-p04-4-5-2-4} - Pin the merged candidate commit before authorizing Phase 5.
