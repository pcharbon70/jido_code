# Harness Autonomous Merge Blocker

## Current Decision

Autonomous merge is blocked. Harness Phase 8 does not add a merge adapter,
merge credential, protected-branch mutation capability, or policy state that
can express autonomous merge authority. Human merge remains mandatory.

## Required Future Decision

Changing this posture requires a separate accepted ADR and a new policy
revision. That decision must bind all of the following evidence:

- an accepted ADR and its digest;
- a passed release gate and its digest;
- production shadow evidence and its digest;
- pull-request outcome evidence and its digest; and
- a tested rollback plan and its digest.

None of those references can amend the current blocker in place. They are
inputs to a future reviewed policy revision, not authority carried by a task,
model output, rollout-stage decision, or pilot request.

## Future Pilot Boundary

Any future pilot remains human-merge shadow work until the future gate passes.
It is limited to reversible, low-risk documentation, dependency-patch,
mechanical-refactor, or test-only tasks. Secret exposure, sandbox escape,
evidence mismatch, protected-branch mutation, or a stale fence disables the
pilot immediately. These conditions remain mandatory regardless of checklist
or evidence state.
