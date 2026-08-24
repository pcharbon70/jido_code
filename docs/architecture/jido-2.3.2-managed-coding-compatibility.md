# Jido 2.3.2 Managed Coding Compatibility

Status: accepted for the Phase 1 disabled runtime baseline

JidoCode pins Jido exactly to `2.3.2`. The managed coding runtime consumes only
immutable agent command output, the strategy snapshot contract, AgentServer
call/state, signal routing, keyed InstanceManager behavior, logical partitions,
and ordinary OTP supervision. Project-owned tests execute these assumptions.

The runtime treats all Jido agent, strategy, directive, process, registry, ETS,
and pod state as disposable. Directives describe effects for the runtime; they
are not authority and cannot independently change durable product truth. Signal
sequence classification detects duplicates, stale delivery, and gaps before a
semantic observation is accepted.

Only `Jido.Storage.ETS` is allowed, as a loss-tolerant process cache. Managed
code must not call hibernate/thaw, `Jido.Persist`, `Jido.Storage.File`,
`Jido.Storage.Redis`, AgentOS persistence, or checkpoint restoration. Destroying
that cache cannot satisfy recovery; recovery starts from graph projections and
their exact profile, strategy, fence, and reconstruction-watermark pins.

InstanceManager is compatible only with `storage: nil`, an explicit partition,
and an infinite idle timeout. Specialist pods remain disabled in Phase 1. Pod
topology, if introduced later, will be a graph-authorized projection rather than
a durable checkpoint.

Later Jido patch releases are incompatible by default. Adoption requires a new
lockfile pin, passing the project-owned compatibility and hostile-boundary
fixtures, clean-checkout CI, and explicit receipt evidence covering every API or
semantic difference. A successful compile alone is not adoption evidence.
