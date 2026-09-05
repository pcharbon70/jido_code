# Repository Wiki Inventory Capacity Successor

- Status: accepted at HUI-C2 merged candidate `da7ab6a4478bb278aa31a7636fa92135843249ff`
- Recorded: 2026-09-05
- Owner: JidoCode knowledge and security maintainers
- Trigger: HUI-C2 source and normative documentation exceed the accepted RW5
  repository-wide byte ceiling

## Decision

The deterministic repository-wiki inventory profile advances from
`wiki-source-inventory/1.0.0` to `wiki-source-inventory/1.1.0`. The total
admitted text ceiling advances from 8,388,608 to 16,777,216 bytes. The 2,000-
file ceiling, 262,144-byte per-file ceiling, 512-byte path ceiling, registered-
root policy, media allowlist, path normalization, symlink gap behavior,
read-stability check, no-repository-execution rule, no-network rule, graph-family
allowlist, and exact zero-model-call/zero-model-token behavior are unchanged.
The profile now also publishes a separate 4,000 visited-path traversal ceiling;
directories and rejected/unsupported paths consume that traversal budget while
the existing 2,000-file ceiling continues to mean accepted text entries.
Directory enumeration and file classification/content reads use fixed,
no-shell Ports through the host's regular, executable, non-group/world-
writable `/usr/bin/timeout`, `/usr/bin/prlimit`, and `/usr/bin/python3.12`
executables. The runtime must identify as CPython 3.12 and receives isolated,
no-site, no-environment flags. It executes only two application-owned constant
helpers whose digests are signed into the profile. `prlimit` applies the CPU,
134,217,728-byte address-space, sixteen-descriptor, and zero-core limits before
Python starts; the helpers repeat those limits, clear standard error, install
a parent-death `SIGKILL` tied to the outer timeout process, set `no_new_privs`,
and install a four-second alarm.

Both helpers open `/`, every absolute root component, and every normalized
relative component descriptor-relatively with `O_NOFOLLOW` and `O_CLOEXEC`;
directory components additionally require `O_DIRECTORY`. The directory helper
stops on the first entry beyond the remaining traversal budget and emits raw
names in two-byte length-prefixed frames followed by an explicit terminal
count. The receiver independently caps every record and the aggregate output,
requires the terminal count, clean EOF, and exit status zero, and rejects any
trailing or partial frame. The file helper classifies the descriptor target,
rejects symlinks and unsupported objects without reading them, checks the
caller-selected limit against the initial regular-file size, streams no more
than that declared size, detects growth and before/after identity or timestamp
changes, and finishes a bounded header/content/terminal protocol. A partial,
overlong, changed, or nonzero response is discarded in full.

The Port environment is empty except for `LC_ALL=C`, its working directory is
`/`, and isolated Python imports no repository path. Neither helper invokes a
shell, hook, repository code, caller-selected command, network, or model. The
file helper reads only a descriptor-relative accepted candidate within the
published per-file bound. Malformed names, malformed or partial protocol
output, a runtime-family mismatch, resource exhaustion, or an unexpected exit
are fatal inventory-boundary failures rather than ordinary unreadable gaps.
`ENOMEM`, `EMFILE`, and `ENFILE` are reserved resource failures; they cannot be
accepted as unreadable gaps. Only an actual non-resource directory/file open or
read failure becomes an unreadable gap; detected mutation becomes a
`changed_during_read` gap.

Every helper call runs in a 4,000,000-word BEAM worker with a 5,000 ms receiver
timeout. An outer GNU `timeout` process is the direct Port child and sends
`SIGKILL` after four seconds; Python's parent-death signal kills it if that
supervisor terminates. Port closure alone is not treated as process-tree
termination. A permit-owning coordinator, independent of the scan caller,
retains its named global lock until the Port worker reaches EOF/status or the
helper deadline cleanup finishes; caller cancellation and early protocol
rejection therefore cannot release a permit while ordinary helper work remains
live. A 60,000 ms traversal deadline reserves a complete helper window before
starting new helper work, and one VM admits at most four live external helper
calls. It does not cap callers waiting outside the helper permit boundary and
is not a whole-`scan/2` wall deadline: final sorting, digesting, and manifest
validation occur after traversal. Producer count/byte ceilings, `prlimit`
CPU/address-space/descriptors, and the four live permits are strict within the
qualified userspace/runtime assumptions. The BEAM `max_heap_size` is a
defensive GC-time kill threshold and may overshoot before collection; it is not
described as an exact allocation intercept. The wall-clock claim also excludes
a process stuck in uninterruptible kernel I/O until the kernel releases it.

This boundary avoids OTP's whole-directory `File.ls`, `:file.list_dir_all`, and
`:prim_file.list_dir_all` materialization as well as later path-based
`File.lstat`/`File.read` content access. Only bounded returned names and bounded
file bodies reach the BEAM. The executable paths, required CPython version
family, script digests, protocols, and resource limits are signed into the
active profile. The path/version checks and script digests do not content-
address the host's Python standard library, ELF interpreter, shared libraries,
`timeout`, or `prlimit`; the Linux/CPython host is therefore an explicit trusted
mutable-host prerequisite, not a pinned or automatically attested runtime. The
candidate records Linux Mint 22.1 (Ubuntu 24.04 base), CPython 3.12.3, GNU
coreutils `timeout` 9.4, and util-linux `prlimit` 2.39.3 as the locally qualified
tuple; GitHub CI currently selects the mutable `ubuntu-24.04` label.
Package/image/platform drift beyond
the checked executable type, permission, and CPython 3.12 family may not fail
closed by itself and requires operator-controlled requalification. A small
content-addressed native helper remains the preferred portability successor.
`execution: :forbidden` continues to prohibit repository code, hooks, imports,
and caller-selected commands; the fixed application-owned inventory helpers
are scanner implementation, not admitted repository work.

Descriptor-relative opens prevent a concurrent rename or symlink swap from
escaping the registered root. Per-directory and per-file before/after checks
detect mutation during each individual operation, but the complete inventory
is not a filesystem snapshot across multiple paths. The source-fence contract
therefore requires the caller-pinned clean checkout to remain free of writers
for the scan; any concurrent mutation, mixed-fence observation, or inability
to preserve that invariant invalidates the inventory and reopens this gate.

The increase is not an unbounded override. Callers may select a smaller closed
file, byte, or path limit, and that smaller limit applies while descendants are
walked; callers cannot exceed any profile maximum. Accumulated entry sets fail
closed when their file/byte envelope is exhausted. The compiler now compares an
inventory to the exact current `SourceInventory.profile().revision` and
recomputes its deterministic manifest digest, so a predecessor, unknown,
malformed, self-inconsistent, or over-capacity inventory fails closed instead
of being accepted by a second literal version list or a digest-shaped
placeholder.

The detached-manifest validator also rechecks the closed manifest schema,
registered paths, graph sources, entry and gap shapes, per-file and aggregate
capacity, registration membership and classification, derived counts,
module-name projection, zero-model accounting, and the recomputed digest
before compilation. The self-hosted pilot retains that bounded manifest inside
its signed evidence and derives every inventory summary from it; a validly
re-signed underreport or over-capacity mutation is therefore rejected. This is
structural and signed-evidence integrity, not a claim that an untrusted caller-
created hash attests filesystem presence, contents, or repository origin;
those remain anchored by scanning the caller-pinned clean checkout under its
source fence.

Because the inventory profile is signed into the qualification component
profiles and affects the self-hosted pilot, the qualification corpus advances
to `repository-wiki-qualification-corpus/1.1.0`; its inventory-file and byte
resource thresholds derive from the same active profile, and its frozen
evaluation instant advances to 2026-09-05 16:00:00 UTC. The pilot advances to
`jido-code-repository-wiki-pilot/1.1.0`. The deterministic V1 release catalog
retains default-off enrollment and zero-model offerings; its derived digest is
renewed by the new bounded supported envelope.

The self-hosted pilot preserves its signed `lib` plus normative-document
inventory scope rather than silently broadening accepted source coverage. Its
test tree remains Git/CI-authoritative and is reported as a visible scope gap;
the successor removes the obsolete implication that the larger ceiling itself
is the reason for that deliberate omission.

## Candidate Evidence

The closure replay pins the immutable merged implementation candidate
`da7ab6a4478bb278aa31a7636fa92135843249ff`. Static profile, runtime,
signed-corpus, report, release-catalog, accounting, and focused-test evidence
is exact at that source fence:

| Evidence | Candidate result |
| --- | --- |
| Inventory profile and limits | `wiki-source-inventory/1.1.0`; profile digest `f61b2fc8cef3ec250007ecb47c4f419ac4e2e8d88488a2838c1f2cf565964f84`; 2,000 files; 16,777,216 total bytes; 262,144 bytes/file; 512 bytes/path; 4,000 visited paths; 4 live helpers |
| Trusted helper host prerequisite and observed runtime tuple | Linux Mint 22.1 / Ubuntu 24.04 base; CPython 3.12.3; GNU `timeout` 9.4; util-linux `prlimit` 2.39.3; mutable-host limitation retained |
| Admitted self-hosted file count and bytes | 1,067 files; 8,642,765 bytes; 786 projected module names; within every accepted limit |
| Inventory/source identity and digest | commit `da7ab6a4478bb278aa31a7636fa92135843249ff`; source revision `e33f921db0286600b0ee0d0f66ba7b223cf92fe5a59394af5cfe2ff88aa11dff`; snapshot `https://jido.run/id/repository-snapshot/16754f0fa799e58a8db75c503814fea3`; fence `rw5-pilot:da7ab6a4478bb278aa31a7636fa92135843249ff`; inventory digest `0f0adbce7fa61aedb1be2986812e01b7ae67337d742dcd7882a32d7d8789366a` |
| Signed corpus revision and digest | `repository-wiki-qualification-corpus/1.1.0`; `78cb7bb49b3d611c2f8d40da3fb5f70d70c562f6b7b83829b1e16efa999e19e9` |
| Security and quality report verification | both admitted and signature-verified; security digest `ea4cfc45360dbadcb809f4c8d01218be35e0851aeb6fca9a0edeab2e9e3280c0`; quality digest `95dc7f66e86fb4ea4e28390c367d361cef9a5208187784611f3eaafec9eb6fc2` |
| Pilot revision, report digest, and admission | `jido-code-repository-wiki-pilot/1.1.0`; report digest `37173b364534ce8ba996d37b79e417d92c54aabd9ddc57d39af26b2e86d6861e`; payload digest `ab1158969f91eadef4e50ed481b4494c9ab1316c184b6594ea2f13d8a74a82e3`; verified and admitted |
| Release catalog digest and publication verification | catalog `9c2eb44d2bc2f41e6203ab0aa46d04a51ecd4e04281fc2743d4716d4d89fda19`; accepted decision `c09d64316eb307c6bd38e0220b146203fdb695423ad31cb2e840bef103707cd3`; default-off, zero-model publication verification passes |
| Model calls, tokens, and cost | exactly 0 calls, 0 input tokens, 0 output tokens, and zero cost |
| Focused repository-wiki test commands/counts | inventory-helper/capacity successor: 17 tests, 0 failures; complete repository-wiki suite: 165 tests, 0 failures in 40.0 seconds |

## Reopening Conditions

The capacity successor is invalid and every dependent HUI-C2/RW5 claim
reopens if the inventory admits more than 2,000 files, 262,144 bytes per file,
16,777,216 bytes in total, 512 bytes per path, or traverses more than 4,000
paths; if an unregistered root,
unsupported media type, unsafe path, symlink escape, changed-during-read file,
or unapproved graph family is treated as accepted source; if repository code,
hooks, network, credentials, or a model become available; if zero call/token/
cost accounting changes; if the compiler accepts a predecessor, malformed,
self-inconsistent, over-capacity, or unknown inventory profile; if a resource threshold and the active profile
diverge; if the pinned clean checkout is writable during scanning, a mixed
source fence can be accepted, the helper process tree or per-VM concurrency is
not bounded, the host helper/runtime identity drifts without requalification,
or a timeout is claimed while uninterruptible kernel I/O is not explicitly
excluded; if any signed corpus/report/pilot/release member changes without full
verification; or if exact-head self-hosted replay, security, quality, resource,
release, architecture, or clean-checkout tests fail.

The accepted RW1-RW5 receipts remain historical evidence for their exact
candidates. This successor does not rewrite those receipts, erase their
reopening conditions, exclude normative HUI-C2 input, or claim that the earlier
8,388,608-byte pilot ran against this candidate.
