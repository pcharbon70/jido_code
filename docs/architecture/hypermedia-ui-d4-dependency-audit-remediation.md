# D4 dependency-audit remediation

Status: **blocked on Decimal advisory reconciliation; no waiver**.

Baseline: merged PR #137, `05f6dcdab0f4a4a7f0494d246908ccbaaa637212`.
Owner: project maintainer / dependency release reviewer.
Review date: 2026-09-08. Recheck on any advisory, lock, source or toolchain change.

## Igniter repair

`mix deps.unlock igniter` followed by `mix deps.get` changes exactly one lock
entry, Igniter 0.8.3 to 0.8.4. No direct constraints or other dependency entries
change. The Hex release archive checksum is
`a9b1cbec996ccb100b4f7d8130129b2dd3f18eb4224ac9a0e907e428ca90dbd7`.
The resulting complete lock SHA-256 is
`185edd5f8bc6a7a82601882c02f08373b8940c2b51770469afa8db644d47acdc`.
The D4 input guard pins these exact bytes and rejects unrelated dependency
changes, checksum changes, mutable refs, and downgrades. Historical receipts
remain evidence for their original candidates, not approval of this update.

[EEF-CVE-2026-82584](https://osv.dev/vulnerability/EEF-CVE-2026-82584)
identifies 0.8.4 as fixed. The
[Hex release record](https://hex.pm/api/packages/igniter/releases/0.8.4)
reports no advisories or retirement. The installed source sanitizes every
publisher-controlled confirmation-panel field before terminal output.

## Decimal conflict remains blocking

Decimal remains at 3.1.1. The
[maintainer advisory](https://github.com/ericmj/decimal/security/advisories/GHSA-rhv4-8758-jx7v)
identifies 3.0.0 as fixed, and the installed 3.1.1 source has default parsing
and output bounds. However, the
[EEF machine-readable record](https://cna.erlef.org/osv/EEF-CVE-2026-32686.json)
has an introduced-at-zero range without a fixed event and explicitly lists
3.1.1 as affected, while its prose says versions before 3.0.0 are affected.
This is a discrepancy requiring upstream reconciliation, not permission to
silence an audit finding. Bounded-input regression tests support investigation
but cannot establish complete exploitability or replace release review.

After the Igniter update, unmodified `mix hex.audit` exits 1 and reports only
Decimal 3.1.1 / EEF-CVE-2026-32686. No `ignore_advisories`, environment ignore,
custom audit filter or CI bypass is introduced. Clean-checkout CI cannot be
declared green until this finding is resolved. An upstream report or explicit
reviewed exception requires maintainer coordination; no such approval is
claimed here.

## Validation

On Elixir 1.19.5 / OTP 28.3.1, `mix precommit` targeting the D4 candidate,
dependency-security, C1 immutability and C5 operations tests passed: 11 tests,
zero failures, plus formatting, strict application compilation and architecture
checks. Dependencies were restored from the locked sources after the checkout
was restored. This focused result is not a full regression, browser or
clean-checkout acceptance claim. The unchanged audit still fails on Decimal.

## D4 boundary

Neither this repair nor PR #137's merge accepts D4. Workstation suspend/resume,
independent security/accessibility/operations review, complete clean-checkout
qualification, and merged-candidate closure remain required. All existing
reopening conditions remain intact.
