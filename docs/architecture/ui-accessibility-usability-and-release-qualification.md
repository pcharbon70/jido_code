# UI Accessibility, Usability, And Release Qualification

- Status: Proposed under ADRs 0008–0011
- Specification version: `0.2.0`
- Owners: JidoCode product, accessibility, security, evaluation, and operations
  maintainers
- Milestone: G — Security And Release Qualification

## Purpose

This specification defines the signed qualification profile and evidence needed
to release the secure hypermedia control plane. Primitive/unit evidence is
insufficient; composed factory workflows must work for several roles, parallel
attempts, browsers, assistive technologies, failures, and real adapters.

## Accessibility Baseline

The target is WCAG 2.2 AA. The supported matrix covers:

- keyboard-only navigation and visible focus;
- screen readers on supported browser/OS combinations;
- 200% zoom, 320 CSS-pixel reflow, text spacing, RTL, and localization growth;
- physical touch and target size;
- reduced motion and forced colors/high contrast;
- CSS-disabled and no-script safe baseline;
- accessible authentication, password managers/paste, passkeys, timeout
  warning/recovery, and step-up form preservation;
- focus and reading-position preservation across fragments;
- non-color status and projection states;
- semantic tables/trees/timelines and graph table/outline alternatives; and
- bounded conversation transcripts, specifically labelled clarification and
  steer forms, preserved drafts, and non-color delivery/conflict state; and
- pause/freeze/new-updates behavior for nonessential auto-updating content.

Event timelines are normal lists/tables by default. Only batched meaningful
outcomes use polite status announcements; urgent assertive alerts are rare and
policy-defined.

## Role-Based Usability Scenarios

Participants include project developers/maintainers, independent verifiers,
factory operators, security auditors/administrators, knowledge stewards, and
cost observers. Tasks include:

1. identify a stalled/risky attempt without opening every workspace;
2. resume and correctly explain three parallel attempts;
3. choose the safest admitted intervention;
4. locate the correct agent conversation, answer a bounded clarification in the
   correct attempt/session/audience, and distinguish recorded, admitted,
   observed, conflicted, and uncertain state;
5. distinguish agent claim from verifier evidence and avoid stale/spoofed
   approval;
6. trace wiki/memory facts to provenance and contradiction;
7. understand direct/transitive Mix dependency posture;
8. recover and determine freshness after stream loss;
9. observe live role revocation safely;
10. resolve a two-human command conflict; and
11. operate an incident under least privilege.

## Outcome Metrics

The signed profile declares thresholds for time-to-detect, time-to-understand,
time-to-safe-intervention, approval correctness, resume accuracy, reconnect
convergence, alert burden, review effort, cost per accepted/observed outcome,
trust calibration, accessibility task completion, and cross-scope isolation.

Zero-tolerance outcomes are defined by the UI threat model. Other thresholds
include sample size, baseline/comparator, confidence treatment, adjudication,
and failure review.

## Technical Release Matrix

- full-page/native fallback and Datastar enhancement;
- all projection, connection, and command states;
- exact supported browsers/OS/AT and responsive modes;
- TLS/HTTP2/proxy/CSP/CSRF/cookie/cache behavior;
- multi-user/tab/project/attempt/interaction-session isolation;
- transcript pagination, session selection, reply context, composer recovery,
  and answer/steer races without focus, draft, or reading-position loss;
- live hints, loss/reorder/duplicate, reconnect, revocation, and deploy restart;
- large fleet/timeline/graph, pagination, virtualization, and backpressure;
- exact ShadcnUI/Dstar/Datastar/Phoenix/assets/dependency provenance;
- real identity, store, projection, runtime, verifier, wiki, cost, and incident
  adapters inside their enabled release posture; and
- install, upgrade, rollback, backup/restore, disable/drain, and on-call drills.

## Evidence Package

The release candidate records code/config/dependency/asset/profile/corpus/
browser/proxy/adapter revisions and digests, commands, test results, manual AT
notes, user-study results, security review, known limitations, thresholds,
incidents, rollback drill, approvers, candidate SHA, and merge provenance.

Evidence from a different component/runtime/browser/profile tuple does not
transfer silently.

## Acceptance And Reopening

Milestone G closes only when all zero-tolerance gates pass, threshold results
meet the signed profile, manual accessibility and usability are independently
reviewed, real-adapter posture matches product claims, operations/rollback are
ready, and the merged candidate is pinned. It reopens on dependency/browser/
profile/policy drift, a new route/lens/action, threshold regression,
accessibility failure, zero-tolerance incident, or stale/absent release evidence.
