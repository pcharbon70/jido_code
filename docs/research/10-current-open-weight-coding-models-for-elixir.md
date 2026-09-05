## 10. Current Open-Weight Coding Models For Elixir

- Status: research baseline and model-selection recommendation, not an accepted
  architecture decision, provider approval, evaluation result, rollout
  authorization, or phase receipt
- Research cutoff: 2026-08-19
- Accepted merged repository baseline inspected:
  `33f7677512cd89202091c3ac7f26ddd18d01b646`
- Related JidoCode research:
  [Coding Agent Evaluations For Development](08-coding-agent-evaluations-for-development.md)
  and
  [Prompt Improvement And Evaluation](09-prompt-improvement-and-evaluation.md)
- Project scope: open-weight model candidates for JidoCode coding, review, and
  repository-analysis profiles, with particular emphasis on Elixir, OTP,
  Phoenix, LiveView, Ecto, and Ash work

## Executive conclusion

No current open-weight model is demonstrated to be specialized for Elixir, and
the available evidence does not establish a statistically defensible Elixir
winner. The evidence supports a candidate set, not a production selection.

JidoCode should begin controlled Elixir evaluation with these roles:

| Role | Initial candidate | Research recommendation |
| --- | --- | --- |
| Best-supported hosted or cluster baseline | GLM-5.2 | Preferred baseline. It leads the current standardized SWE-rebench open-weight results and is competitive on the small real-repository Elixir slice. |
| Maximum-capability challenger | Kimi K3 | Include as the frontier challenger. Its publisher and independent general-agent evidence is strong, but it is too new for the current SWE-rebench window and its custom license needs separate review. |
| Quality-first local candidate | Qwen3.6-27B | Preferred workstation candidate where a quantized dense 27B model and useful context fit. Publisher coding results favor it over Qwen3.6-35B-A3B. |
| Throughput-first local candidate | Qwen3.6-35B-A3B | Include where approximately 3B active parameters materially improve local latency. A current Elixir/Phoenix/Ash practitioner report shows it operating on 32 GB unified memory. |
| General hosted alternatives | MiniMax M3 and DeepSeek V4 Pro | Retain as comparison arms, not preferred Elixir defaults. MiniMax M3 is strong in aggregate but weaker in the available Elixir slice; DeepSeek V4 Pro trails GLM-5.2 on standardized repository work. |

This is intentionally not a recommendation to bind a mutable provider alias to
a production profile. The object that must be evaluated is the complete pinned
system:

> model snapshot + provider + access profile + reasoning effort + sampling +
> context policy + agent scaffold + prompts + tools + retrieval + memory +
> sandbox + budgets + repository revision + verifier

That follows the evaluation boundary already established by JidoCode [JC01]. A
different harness, context compiler, tool contract, reasoning budget, or model
snapshot can reverse a model ranking.

The strongest practical conclusion is therefore:

1. use GLM-5.2 as the hosted reference target;
2. evaluate Kimi K3 as the likely frontier challenger;
3. compare Qwen3.6-27B and Qwen3.6-35B-A3B for local operation;
4. require Elixir-specific, repository-native, repeated evaluation before any
   rollout choice; and
5. keep JidoCode's existing verification, security, and phase-closure gates
   independent of public leaderboard results.

## Authority and non-goals

This report is advisory research. It does not:

- accept a model, provider, quantization, inference engine, or remote endpoint;
- authorize source disclosure, provider tool execution, delegated CLI use, or
  an increase in agent autonomy;
- change any accepted architecture, threat-model control, phase gate, or gate
  reopening condition;
- prove that a model's published context length is usable within JidoCode's
  latency, cost, privacy, or evidence bounds;
- treat a model license as legal advice or as an approval for JidoCode use; or
- treat a public benchmark, blog experiment, or practitioner report as a
  JidoCode evaluation result.

Model availability and provider behavior are mutable external facts. Any later
evaluation must pin an immutable model identifier where the provider exposes
one, record the exact provider and inference parameters, retain the applicable
license text or digest, and fail closed when a requested snapshot resolves to a
different artifact [JC01-JC02].

## Scope and research questions

This report answers five questions:

1. Which current downloadable-weight models are credible coding candidates?
2. Which claims come from standardized independent evaluation rather than a
   model publisher's own harness?
3. What direct evidence exists for Elixir, Phoenix, OTP, Ecto, or Ash work?
4. How do licensing and deployment scale constrain otherwise strong models?
5. Which candidates should enter a controlled JidoCode evaluation?

The report compares models available by the research cutoff whose weights can
be downloaded or self-hosted. Closed-weight models appear only as context in
source benchmarks; they are not candidate recommendations.

The report does not attempt a training-corpus audit. No reviewed source proves
that one current candidate received a uniquely representative or
quality-controlled Elixir/Phoenix/OTP training mixture. Claims that a model is
"good at Elixir" are therefore grounded in measured behavior or clearly
identified practitioner evidence, not inferred from vendor descriptions.

## Research method

### Source collection

The source set includes:

- official model cards, repositories, technical reports, and license texts;
- peer-reviewed or conference-published multilingual-code research;
- current benchmark methodology, public leaderboards, and public run records;
- independent benchmark audits and model-analysis articles;
- Elixir ecosystem engineering articles; and
- Elixir Forum and Reddit discussions for recurring operational observations.

Searches covered current open-weight coding models, multilingual code
generation, Elixir-specific benchmark columns, real-repository software
engineering tasks, local inference reports, and recurring Phoenix/Ash/OTP
failure modes. Vendor claims were checked against independent evaluations when
a comparable evaluation existed.

### Evidence hierarchy

| Tier | Evidence | Permitted use in this report |
| --- | --- | --- |
| A | Official license text for licensing facts; peer-reviewed papers; benchmark methodology plus public raw records; standardized independent evaluations | May support factual model constraints, benchmark interpretation, and the initial candidate set. |
| B | Current preprints, independent benchmark audits, and transparent executable experiments | May support directional conclusions and evaluation design; does not alone authorize a model. |
| C | Vendor model cards, technical reports, and publisher-run benchmark tables | May establish publisher-stated architecture, context, serving requirements, and claimed performance. Performance claims require the publisher label and are not compared as if harnesses were identical. |
| D | Engineering blogs, individual practitioner reports, and forums | May identify hypotheses, usability evidence, and failure modes. It cannot establish a population-level ranking. |

Official model documentation is primary evidence for parameter counts and the
publisher's intended serving protocol, but it is not independent evidence for
performance. Conversely, a third-party leaderboard can compare behavior under
one harness but cannot prove the model will behave the same under JidoCode.

### Reproduced benchmark snapshots

Two mutable benchmark surfaces were captured at the cutoff:

- SWE-rebench displayed a 2026-05-15 through 2026-07-01 window containing 111
  problems from 65 repositories. The visible leaderboard values in this report
  were retrieved on 2026-08-19 [CB01-CB02].
- Senior SWE-Bench exposed a manifest generated at
  `2026-08-14T00:23:15.879082+00:00`, with 156 task records, 61 agents, and
  4,987 run records. Its current aggregate uses 95 eligible hard tasks for most
  agents, after five of the original 100 benchmark families were excluded from
  the refreshed quality-gated set [CB03-CB05].

These are time-bounded observations. The URLs are live leaderboards and may no
longer display the same values after the cutoff.

### Original Elixir-slice analysis

Senior SWE-Bench is the only current reviewed benchmark found that exposes both
recent open-weight candidates and real public repositories with Elixir tasks.
The report therefore performs a small secondary analysis of its public data.

The extraction procedure was:

1. select public families with `in_benchmark == true` and supported hard-task
   records;
2. retain families whose `taxonomy.stack` contains `elixir`;
3. select the hard-task run for GLM-5.2, Kimi K3, and MiniMax M3;
4. expand the public `passk_metrics` array into the three scheduled attempts;
5. calculate basic correctness and the benchmark client's current "tasteful"
   predicate;
6. treat a benchmark-marked cheating or invalid attempt as unsuccessful in the
   conservative scheduled-attempt rate;
7. calculate tasks solved at least once across three scheduled attempts; and
8. calculate Wilson 95% intervals for the primary scheduled-attempt rates.

The result contains ten task families: six Electric, one Firezone, and three
Plausible tasks. There are five bug fixes, four features, and one performance
task. This is materially closer to production Elixir work than a translated
function-generation benchmark, but it remains a small, non-random sample.

The benchmark documentation and current client calculation disagree on one
edge case. The prose describes a rubric score greater than 0.5 as a tasteful
gate. The current client predicate permits the rubric to be absent or greater
than 0.5, while still requiring correctness, bloat below 2x, practice above 2,
and relative taste above 2 [CB03-CB04]. This report preserves the leaderboard's
client-compatible result and reports a strict-rubric sensitivity result. It
does not silently select the interpretation that favors one model.

### Checks not performed

This research did not:

- execute any candidate model against JidoCode;
- audit model weights, training data, or inference-engine code;
- test exact quantizations or local throughput;
- verify provider privacy, retention, residency, or contractual controls;
- reproduce every publisher benchmark; or
- perform legal review of model licenses.

Those omissions prevent this document from serving as rollout evidence.

## Terminology

| Term | Meaning in this report |
| --- | --- |
| Open-source AI | AI for which the preferred form for modification, including the required data information, code, and parameters, is available under the freedoms described by the Open Source AI Definition [OS01]. |
| Open-weight model | A model whose parameters can be downloaded, regardless of whether its data, complete training pipeline, or license satisfies the Open Source AI Definition. |
| Permissively licensed release | A release whose published model artifact uses a familiar permissive license such as MIT or Apache-2.0. This does not prove full training openness or resolve every downstream legal question. |
| Custom-license release | A release with additional use, revenue, attribution, field-of-use, or authorization conditions. |
| Total parameters | All stored model parameters. For a sparse MoE model, these largely determine weight storage and distribution requirements. |
| Activated parameters | The approximate parameters used for one token. They influence compute, but do not mean inactive expert weights can be omitted from storage. |
| Context length | Publisher-stated maximum token window. It is not evidence of useful recall, affordable serving, or JidoCode compatibility at that length. |
| Model result | A result intended to isolate a model under a fixed scaffold, prompt, and environment. |
| Agent result | A result for a complete model-plus-harness system. It cannot be attributed to the model alone. |
| Basic solve | Senior SWE-Bench `correctness == 1` for the evaluated attempt. |
| Tasteful solve | A Senior SWE-Bench correctness result that also passes its quality, bloat, practice, and relative-taste gates. |
| `pass@k` | Probability or observed rate that at least one of `k` attempts succeeds. It must not be reported as first-attempt capability. |
| `pass^k` | Consistency measure in which all `k` attempts succeed. |

### Why this report uses "open-weight"

The Open Source Initiative's Open Source AI Definition requires more than
downloadable parameters. It includes sufficient information about training
data and the code used to process data and train the system [OS01]. The reviewed
model releases vary substantially on those dimensions. Calling every one
"open source" would erase a material distinction.

Kimi K3 and MiniMax M3 also use custom licenses:

- Kimi K3 requires a separate Moonshot agreement when a licensee or affiliate
  operates a model-as-a-service business and aggregate revenue exceeds USD 20
  million over a consecutive twelve-month period. It also requires prominent
  `Kimi K3` display for certain products above 100 million monthly active users
  or USD 20 million monthly revenue [LC01].
- MiniMax M3 grants non-commercial rights, requires `Built with MiniMax M3` for
  commercial use, requires a one-time notice below USD 20 million annual
  product or service revenue, and requires prior authorization above that
  threshold. It also includes prohibited-use conditions [LC02].

GLM-5.2 is published under MIT, Qwen3.6 under Apache-2.0, and DeepSeek V4 Pro
under MIT according to their current model cards [MD02, MD04-MD06]. Those labels
make them easier licensing candidates; they do not by themselves prove OSI
Open Source AI conformance.

## Current model landscape

### Candidate summary

| Model | Publisher-stated scale and context | Published artifact license | Practical class | Research assessment |
| --- | --- | --- | --- | --- |
| Kimi K3 | 2.8T total, 104B activated, 1,048,576-token context, native MXFP4 weights [MD01] | Kimi K3 License [LC01] | Datacenter cluster or API | Strongest frontier open-weight candidate, but custom-license and not yet present in the current SWE-rebench window. |
| GLM-5.2 | Approximately 743B total and 39B activated in the serving recipe; 1M-token context [MD02-MD03] | MIT [MD02] | Datacenter cluster or API | Best-supported standardized coding baseline at the cutoff. |
| MiniMax M3 | Approximately 428B total, 23B activated, 1M-token context [MD04] | MiniMax Community License [LC02] | Datacenter cluster or API | Strong aggregate senior-task performance; custom license and weaker small Elixir slice. |
| DeepSeek V4 Pro | 1.6T total, 49B activated, 1M-token context [MD05] | MIT [MD05] | Datacenter cluster or API | Permissive large-model alternative, behind GLM-5.2 on current SWE-rebench. |
| Qwen3.6-27B | Dense 27B; 262,144 native context, extensible by the publisher to approximately 1.01M [MD06] | Apache-2.0 [MD06] | Workstation or server when quantized | Quality-first local candidate. |
| Qwen3.6-35B-A3B | 35B total, approximately 3B activated; 262,144 native context [MD07] | Apache-2.0 [MD07] | Workstation or server when quantized | Throughput-first local candidate; activation sparsity does not reduce stored weights to 3B. |
| Qwen3-Coder-Next | 80B total, approximately 3B activated; 256K context [MD08] | Apache-2.0 [MD08] | Large workstation or server | Efficient coding-specialist reference, but newer general Qwen3.6-27B evidence is stronger. |
| Kimi K2.7 Code | 1T total, 32B activated; 256K context [MD09] | Modified/custom model license [MD09] | Cluster or API | Coding-specialist comparison candidate; superseded for maximum capability by Kimi K3 and lacking direct current Elixir results. |

Parameter counts do not compare quality. They describe deployment pressure. A
35B MoE model with 3B activated parameters may generate much faster than a 27B
dense model, but it still needs all expert weights available. A one-million
token advertised context can also require prohibitive KV-cache memory or
latency long before the nominal limit.

### Kimi K3

Moonshot describes Kimi K3 as a native multimodal, long-horizon agentic model
using 2.8T total parameters, 104B activated parameters, and a one-million-token
context [MD01]. Its publisher table reports 67.5 on DeepSWE, 77.8 on
ProgramBench, 88.3 on Terminal-Bench 2.1, 81.2 on FrontierSWE, and 42.0 on
SWE-Marathon [MD01].

Those numbers are evidence that K3 belongs in the candidate set, not a clean
cross-model ranking. The publisher footnotes disclose different harnesses
across models and benchmarks, including Kimi Code, Claude Code, Codex,
Terminus-2, and mini-SWE-agent. Some comparison values are adopted from third
parties rather than rerun under one environment [MD01].

Independent broad analysis placed Kimi K3 near the leading closed models on a
general intelligence index and especially strong on agentic knowledge work
[IA01-IA02]. That is useful frontier evidence, but it is not Elixir evidence and
not a substitute for repository coding trials.

The current SWE-rebench leaderboard does not include Kimi K3. K3 was released
after the displayed benchmark window closed. Its absence must be recorded as
missing evidence, not interpreted as a zero or as proof that GLM-5.2 is the
stronger model overall.

### GLM-5.2

GLM-5.2 is the most defensible initial hosted baseline because three favorable
facts align:

1. it leads the current standardized open-weight SWE-rebench entries;
2. it remains competitive in Senior SWE-Bench and the public Elixir slice; and
3. its published artifact uses MIT rather than a revenue- or attribution-gated
   custom license [CB01, CB03, MD02].

The publisher reports 62.1 on SWE-bench Pro, 48.9 on NL2Repo, 46.2 on DeepSWE,
63.7 on ProgramBench, and 82.7 as its best reported Terminal-Bench 2.1 harness
result [MD02]. These values are orientation only because the harness and
context differ by benchmark.

GLM-5.2 is not a normal workstation model. An inference recipe identifies
approximately 743B stored parameters and 39B activated parameters. Even a
low-bit representation remains a multi-accelerator deployment after runtime,
KV cache, and serving overhead [MD03]. "Local deployment supported" in a model
card means self-hostable infrastructure, not consumer-device fit.

### MiniMax M3 and DeepSeek V4 Pro

MiniMax M3 is a serious general coding-agent candidate. It slightly leads Kimi
K3 and GLM-5.2 on the current aggregate Senior SWE-Bench tasteful rate, and it
is second among these released models on SWE-rebench [CB01, CB03]. Its custom
commercial license and weaker observed Elixir slice keep it from being the
preferred Elixir baseline.

DeepSeek V4 Pro has a permissive MIT release and a very large one-million-token
MoE architecture [MD05]. It scores below GLM-5.2 and MiniMax M3 on the current
SWE-rebench display. It remains useful as a price, provider, and architecture
comparison arm, but the reviewed evidence does not make it the first Elixir
choice.

### Qwen3.6 local candidates

Qwen3.6-27B is the quality-first local recommendation. In Qwen's own fixed
table it scores above Qwen3.6-35B-A3B on SWE-bench Verified, SWE-bench Pro,
SWE-bench Multilingual, Terminal-Bench 2.0, SkillsBench, and NL2Repo [MD06].
Publisher numbers do not establish JidoCode performance, but the consistent
within-publisher comparison justifies evaluating the dense model for quality.

Qwen3.6-35B-A3B is the throughput candidate. Only approximately 3B parameters
are active per token, while the full approximately 35B weights remain resident.
One Elixir Forum practitioner reports running a Q4_K_M quantization through
Ollama and OpenCode on a 32 GB M2 Max for Elixir/Phoenix/Ash work. The author
used issue specifications, skills, TDD, `mix test`, and `mix precommit`, and
reported similar same-spec branches from Qwen and Sonnet [EL03]. This is useful
operability evidence, not an independent quality benchmark.

At four bits, raw weight arithmetic is approximately 13.5 GB for 27B and 17.5
GB for 35B before quantization metadata, runtime buffers, vision components,
KV cache, and context growth. A 24 GB device may be workable for Qwen3.6-27B at
bounded context; 32 GB or more provides a safer operating margin. These are
planning estimates, not measured JidoCode capacity evidence.

## What standardized general coding benchmarks show

### SWE-rebench

SWE-rebench continuously collects real GitHub tasks and is designed to reduce
contamination and scaffold-driven incomparability. It runs a fixed minimal
ReAct-style agent, identical prompts, developer-recommended sampling, and a
standard 128K context. It reports repeated-run variance rather than selecting
only the best trajectory [CB01-CB02].

The visible 2026-05-15 through 2026-07-01 snapshot contained 111 problems from
65 repositories:

| Open-weight model | Resolved rate | Reported uncertainty | Pass@5 |
| --- | ---: | ---: | ---: |
| GLM-5.2, high effort | 62.9% | +/- 1.19% | 81.1% |
| MiniMax M3 | 47.2% | +/- 1.13% | 69.4% |
| MiMo V2.5 Pro | 46.5% | +/- 0.54% | 65.8% |
| DeepSeek V4 Pro, high effort | 40.2% | +/- 1.29% | 64.0% |
| Qwen3.6-27B | 31.2% | +/- 1.68% | 57.7% |
| Qwen3.6-35B-A3B | 24.7% | +/- 0.79% | 43.2% |

Source: current leaderboard and methodology [CB01-CB02].

This is the strongest independent reason to choose GLM-5.2 as the first hosted
baseline. It is not evidence that GLM-5.2 is best at Elixir. The current data
behind the displayed window contains Python, Rust, TypeScript, Go, and Java;
it contains no Elixir tasks.

SWE-rebench V2 is promising for future Elixir evaluation. Its paper reports
32,079 retained executable tasks across 20 languages and 3,617 repositories.
The larger candidate inventory contains 6,621 Elixir tasks from 563
repositories [CB06]. The current public model leaderboard has not evaluated
that Elixir pool, so it cannot yet rank these models for Elixir.

### Senior SWE-Bench aggregate

Senior SWE-Bench uses recent merged pull requests to construct deliberately
underspecified, senior-level tasks. A "tasteful" solve requires executable
correctness plus validation and quality gates concerning the task rubric,
patch bloat, repository practice, and code quality relative to the oracle
[CB03-CB05]. It is closer to long-horizon product work than isolated function
generation.

The current open-weight aggregate is:

| Model | Basic solves | Basic rate | Tasteful solves | Tasteful rate |
| --- | ---: | ---: | ---: | ---: |
| MiniMax M3 | 39/95 | 41.1% | 20/95 | 21.1% |
| Kimi K3 | 38/94 | 40.4% | 19/94 | 20.2% |
| GLM-5.2 | 34/95 | 35.8% | 17/95 | 17.9% |

Source: current agents leaderboard [CB03].

This reverses the order seen on SWE-rebench: MiniMax M3 and Kimi K3 lead
GLM-5.2. The difference is not a contradiction. Senior SWE-Bench measures a
different task distribution, uses a different harness and budget, and adds
quality judgments beyond test completion. The result demonstrates why a model
name cannot be evaluated independently of its system tuple.

## Direct Elixir evidence

### Senior SWE-Bench public Elixir slice

The ten public Elixir families are:

| Repository | Family |
| --- | --- |
| Electric | `electric-feat-add-variadic-function` |
| Electric | `electric-feat-sync-service-start` |
| Electric | `electric-fix-classify-admission-control` |
| Electric | `electric-fix-elixir-client-cache` |
| Electric | `electric-fix-resolve-pending-shapes` |
| Electric | `electric-perf-array-filter-eval` |
| Firezone | `firezone-feat-portal-add-recent` |
| Plausible | `plausible-feat-shared-dashboard-deeplink` |
| Plausible | `plausible-fix-cross-site-resource-attach` |
| Plausible | `plausible-fix-top-pages-comparison` |

These tasks exercise expression evaluation, database connection lifecycle,
admission control, cache behavior, WAL progress, performance, Phoenix UI,
sharing, authorization-sensitive attachment, and analytics behavior. They do
not cover every JidoCode concern, but they are substantially more
repository-native than algorithm translations.

The conservative scheduled-attempt result is:

| Model | Basic success | Client-compatible tasteful | Strict-rubric tasteful | Tasks with at least one basic solve | Tasks with at least one client-compatible tasteful solve |
| --- | ---: | ---: | ---: | ---: | ---: |
| GLM-5.2 | 14/30, 46.7% | 8/30, 26.7% | 5/30, 16.7% | 6/10 | 5/10 |
| Kimi K3 | 13/30, 43.3% | 7/30, 23.3% | 7/30, 23.3% | 5/10 | 3/10 |
| MiniMax M3 | 8/30, 26.7% | 4/30, 13.3% | 2/30, 6.7% | 5/10 | 2/10 |

Three Kimi K3 attempt metrics were benchmark-marked as cheating or invalid and
had no correctness value. The conservative table counts every scheduled
attempt in the denominator and grants those attempts no success. If the
benchmark's non-cheating denominator is used instead, Kimi K3 has 13/27 basic
successes, or 48.1%, and 7/27 client-compatible tasteful successes, or 25.9%.
GLM-5.2 remains 14/30 and 8/30. That denominator choice changes the small basic
ordering.

The approximate Wilson 95% intervals under the conservative denominator are:

| Model | Basic interval | Client-compatible tasteful interval |
| --- | ---: | ---: |
| GLM-5.2 | 30.2%-63.9% | 14.2%-44.5% |
| Kimi K3 | 27.4%-60.8% | 11.8%-40.9% |
| MiniMax M3 | 14.2%-44.5% | 5.3%-29.7% |

Every relevant interval overlaps. The strict-rubric sensitivity also moves
Kimi K3 ahead of GLM-5.2 on trial count, while the current client-compatible
predicate slightly favors GLM-5.2. The only defensible interpretation is:

- GLM-5.2 and Kimi K3 both belong in the Elixir evaluation;
- MiniMax M3's aggregate advantage did not reproduce on this tiny public
  Elixir slice;
- GLM-5.2 has a weak client-compatible tasteful signal, not a proven lead; and
- no model can be called best at Elixir from these ten tasks.

### AutoCodeBench and the Elixir 97.5 claim

AutoCodeBench contains 3,920 executable problems and 37,777 tests distributed
across 20 languages. It evaluates one-shot code generation rather than
repository editing [CB07-CB08]. Its ICLR 2026 AutoCodeBench-Lite table reports,
among the then-tested open-weight models:

| Model | Elixir pass@1 |
| --- | ---: |
| Qwen3-235B-A22B-Thinking-2507 | 68.9% |
| Kimi K2-0711 Preview | 63.9% |
| Qwen3-Coder-480B-A35B | 59.0% |
| Qwen2.5-Coder-32B | 52.5% |

Qwen3-235B-A22B-Thinking is therefore the strongest open-weight model tested
in that Elixir Lite table. It is not the strongest current Elixir model by
extension: Kimi K3, GLM-5.2, MiniMax M3, DeepSeek V4 Pro, and Qwen3.6 were not
in the comparison [CB08].

The widely repeated Elixir `97.5` is the full benchmark's **current upper
bound**. A task counts if any of more than thirty evaluated models solved it.
It represents approximately 193 of 198 Elixir tasks solved by at least one
model, not a 97.5% score by one model [CB07, EL01].

Several construction details constrain interpretation:

- Elixir tasks follow an approximate Python-to-Elixir translation path rather
  than a native Phoenix, OTP, Mix, Ecto, or Hex issue distribution.
- DeepSeek-Coder-V2-Lite filters easy tasks by attempting each problem ten
  times. The paper itself notes that a weaker filter in low-resource languages
  can leave a different difficulty distribution.
- Elixir was not among the six languages included in the paper's manual
  validation sample.
- AutoCodeBench-Lite reduces Elixir from 198 to 61 tasks, which is compatible
  with a non-equivalent difficulty distribution but does not by itself prove
  that the Elixir tasks are easy.

An independent methodological audit develops these limitations in detail
[IA03]. AutoCodeBench remains valuable multilingual execution evidence; it
cannot prove that Elixir is inherently easiest for models or predict
repository-level Phoenix performance.

### McEval

McEval provides human-curated completion, understanding, and generation tasks
across 40 languages and includes Elixir [CB09]. It is useful historical evidence
that multilingual evaluation need not begin from Python translation. Its model
roster predates the current candidate set, and its tasks do not reproduce
Phoenix/OTP repository work. It therefore informs corpus design but not the
2026 model choice.

### Advent of Code agent experiment

A transparent February 2026 blog experiment ran ten Elixir Advent of Code
parts, covering days one through five, through the same agent setup [EL02].
Kimi K2.5 completed all ten in 260 seconds and 12,268 output tokens, narrowly
ahead of Claude Opus 4.6 at 272 seconds. Qwen3.5 Plus completed them in 356
seconds and GLM-5 in 1,476 seconds. Qwen3-Coder-Next failed on day 1 part 2,
Devstral failed on day 1 part 1, and seven of ten models completed the full
Elixir set.

This is a useful executable signal for the Kimi lineage. It is one run of ten
algorithmic puzzle parts, and the exact current models were not tested. It does
not justify transferring the Kimi K2.5 result directly to Kimi K3 or from
algorithms to Phoenix architecture.

## Why Elixir may work well with coding agents

Dashbit proposes several plausible mechanisms [EL01]:

- immutability and explicit data transformation improve local reasoning;
- module-qualified functions reduce implicit receiver and dispatch ambiguity;
- first-class documentation and doctests provide executable training signal;
- ecosystem stability reduces contradictory version-specific examples;
- compilation, warnings, ExUnit, and Mix provide fast structured feedback;
- the BEAM reduces the number of auxiliary services required for many
  applications; and
- runtime introspection gives agents observable process and application state.

These are credible engineering hypotheses, especially for an iterative agent
that can compile, test, inspect dependencies, and query a running application.
AutoCodeBench does not isolate these mechanisms, so the article must not be
treated as causal proof.

JidoCode can nevertheless exploit the mechanisms directly. Its harness can
provide exact dependency documentation, compiler diagnostics, targeted ExUnit
tests, repository-native Mix tasks, and bounded runtime observations. That is a
more reliable intervention than assuming a model internalized the correct
Phoenix version or OTP abstraction during training.

## What practitioner evidence says goes wrong

The community record is mixed. Some practitioners report excellent shipped
results with specifications, small scopes, skills, Tidewave or documentation
tools, tests, and strict Credo rules. Others report N+1 queries,
overcomplication, naming problems, dense conditionals in place of function
heads and guards, object-oriented abstractions, and poor process choices
[EL03-EL05].

A current Ash-focused Credo plugin discussion provides unusually concrete
failure patterns [EL06]:

- fetching a whole dataset and then using `Enum.filter/2` or `Enum.reject/2`
  instead of expressing the query through the resource and database;
- constructing ad hoc Ash queries rather than using reviewed domain actions
  and interfaces;
- leaving redundant wrapper functions after refactoring;
- giving actions and interfaces inconsistent names or leaking action options
  through interfaces;
- bypassing policy with `authorize?: false`, including in tests; and
- using `send(self(), ...)` or arbitrary processes in LiveViews instead of
  `start_async/3`, `assign_async/3`, tasks, or appropriate supervision.

These reports support a key distinction:

> Elixir syntax is usually not the limiting problem. Architectural and
> framework-semantic correctness is.

A model can produce compiling Elixir while still violating data locality,
authorization, supervision, process ownership, LiveView lifecycle, query
efficiency, or project vocabulary. Those errors are poorly measured by
function-generation benchmarks and can survive ordinary happy-path tests.

The repository's `AGENTS.md` already addresses many of these risks: it pins
Phoenix 1.8 patterns, requires `to_form/2`, imported inputs and icons, streams,
authenticated route placement, explicit DOM IDs, non-deprecated navigation,
idiomatic Elixir access and rebinding, and `mix precommit`. That instruction set
is not proof of compliance. It is a useful treatment that must be included in
the evaluated prompt bundle and tested against variants [JC02-JC03].

## Deployment and operability constraints

### Local does not mean single-device

All reviewed weights are self-hostable in the broad sense, but only the Qwen
27B and 35B candidates are normal workstation targets. Approximate four-bit raw
weight sizes illustrate the difference:

| Model | Approximate raw 4-bit weight arithmetic | Expected deployment class |
| --- | ---: | --- |
| Qwen3.6-27B | 13.5 GB | Workstation with bounded context |
| Qwen3.6-35B-A3B | 17.5 GB | Workstation with bounded context |
| Qwen3-Coder-Next 80B | 40 GB | Large unified-memory machine or server |
| MiniMax M3 428B | 214 GB | Multi-accelerator server or cluster |
| GLM-5.2 approximately 743B | 371.5 GB | Multi-accelerator cluster |
| DeepSeek V4 Pro 1.6T | 800 GB | Large cluster |
| Kimi K3 2.8T | 1.4 TB | Large cluster |

These figures are parameter-count arithmetic, not serving measurements. Real
memory is higher and depends on native precision, quantization metadata,
non-expert weights, runtime workspaces, sharding, KV cache, batch size, and
context. Kimi K3's published native MXFP4 design and sparse-attention models
may materially change compute and cache behavior without making their complete
weights workstation-sized [MD01, MD04-MD05].

### Long context is a treatment, not a free capability

One-million-token context claims should not cause JidoCode to send an entire
repository indiscriminately. Long prompts can:

- increase prefill time and cost;
- dilute relevant evidence;
- expose more untrusted instructions;
- increase compaction and provider-specific behavior;
- make local KV cache exceed available memory; and
- obscure whether improvement came from the model or from extra information.

JidoCode should evaluate each candidate with the same bounded context policy
first, then run a separate context-budget treatment. That keeps model selection
distinct from retrieval and prompt-assembly optimization [JC01-JC02].

### Provider and inference compatibility

Kimi K3 requires preserved thinking history for multi-turn use according to its
model documentation: the complete assistant message, including reasoning and
tool-call fields, is passed back on later turns [MD01]. Other candidates expose
different reasoning-effort, tool-call parser, and sampling conventions. An
adapter that drops or rewrites those fields may create a false negative, while
a provider-native harness can create an unfair advantage.

The evaluation must therefore record:

- immutable model and tokenizer identity;
- provider and endpoint identity;
- inference engine and version for self-hosted models;
- quantization and tensor format;
- chat template and reasoning-history policy;
- tool-call parser and schema;
- temperature, top-p, top-k, reasoning effort, and output limit;
- context window and context-policy revision; and
- retry, timeout, compaction, and failure behavior.

## Recommended JidoCode evaluation

### Candidate set

The first Elixir model comparison should include:

1. GLM-5.2 at a pinned high or maximum supported effort;
2. Kimi K3 at a pinned supported effort;
3. Qwen3.6-27B at one pinned quantization and inference engine;
4. Qwen3.6-35B-A3B at one pinned quantization and inference engine; and
5. one of MiniMax M3 or DeepSeek V4 Pro as an additional hosted control if
   budget permits.

Every treatment must use the same JidoCode scaffold, tool surface, repository
instructions, context policy, task statement, execution limits, and verifier
unless the experiment explicitly studies one of those variables. Provider
recommended sampling may be recorded as a separate treatment rather than
silently changing parameters per model.

### Corpus

Build at least a pilot corpus of 30 fresh or private JidoCode and Elixir tasks,
balanced across:

| Track | Required task characteristics |
| --- | --- |
| Elixir language and refactoring | Pattern matching, guards, pipelines, immutable transformations, structs, protocols, typespecs, and maintainability-sensitive refactors |
| Phoenix and LiveView | Authenticated routing, assigns, forms, streams, async work, HEEx, navigation, component contracts, and DOM behavior |
| Ecto and Ash | Database-side filtering, transactions, changesets, resource actions, domain interfaces, actor propagation, policy enforcement, and N+1 avoidance |
| OTP and concurrency | Process ownership, supervision, failure propagation, back-pressure, tasks, registries, lifecycle, cancellation, and recovery |
| Build and operations | Mix tasks, dependency/API-version use, configuration, releases, telemetry, and warnings-as-errors |
| JidoCode architecture and security | Graph authority, semantic commands, closed schemas, tool mediation, evidence boundaries, secrets, and prohibited effects |

Use real issue-shaped tasks with exact repository baselines. Include bug fixes,
features, refactors, performance work, review tasks, and repository analysis.
Keep visible developer checks distinct from verifier-owned hidden and
compositional checks. Add negative controls in which no change, a narrower
change, or a refusal is correct [JC01].

### Repetition and metrics

Run at least three independent attempts per model-task treatment. Report:

- accepted pass@1 and Wilson interval;
- accepted `pass^3` consistency;
- task-level at-least-one-of-three as diagnostic `pass@3`, never as pass@1;
- compile, targeted-test, full-test, and `mix precommit` outcomes separately;
- hidden-test and mutation strength;
- prohibited-effect and authorization outcomes separately from utility;
- patch size and unnecessary-file rate;
- human-reviewed idiomaticity and architecture scores;
- time to first valid patch, wall time, token use, and provider cost;
- tool-call, retry, timeout, and compaction rates; and
- evaluator disagreement and adjudication rate.

A solution that bypasses authorization, weakens tests, filters protected data
in memory, violates a process boundary, or mutates outside the allowed scope is
not a successful solve even when visible tests pass.

### Elixir quality rubric

The blinded human rubric should score at least:

1. correctness against the task and hidden behavior;
2. idiomatic pattern matching, guards, pipelines, and data transformation;
3. correct OTP ownership, supervision, and failure semantics;
4. Phoenix/LiveView lifecycle and HEEx correctness;
5. query placement, preload behavior, and N+1 risk;
6. Ash/Ecto authorization and actor propagation;
7. API consistency with the repository's contexts, resources, and vocabulary;
8. test quality without test weakening or implementation coupling;
9. minimality, readability, and absence of speculative abstractions; and
10. adherence to the exact repository `AGENTS.md` and dependency versions.

Reviewers should not know which model produced a patch. A model-based judge may
assist triage only after calibration against human labels and must never be the
sole acceptance oracle [JC01].

### Selection rule

Do not select a model from one aggregate score. A candidate is eligible only if
it:

- has no critical prohibited-effect or authorization failure in the sealed
  evaluation;
- meets the accepted correctness and consistency floor for its profile;
- does not materially regress any critical Elixir track;
- has reproducible provider or self-hosted identity;
- passes license, privacy, retention, residency, and operational review;
- fits the profile's latency, cost, and capacity bounds; and
- wins or is non-inferior on the profile-specific utility vector.

Separate profiles may legitimately choose different models. A local analysis
profile may prefer Qwen3.6-35B-A3B for latency, while a difficult hosted editing
profile prefers GLM-5.2 or Kimi K3. One mutable "best model" setting would hide
those tradeoffs.

## Research limits and confidence

| Finding | Confidence | Reason |
| --- | --- | --- |
| No current candidate is proven Elixir-specialized | High | No reviewed model report or independent benchmark establishes specialization, and current Elixir evidence is sparse. |
| GLM-5.2 is the best-supported hosted baseline | Moderate-high | It leads a standardized fresh-task benchmark, has a permissive published license, and is competitive in the real Elixir slice. Kimi K3 is absent from that standardized window. |
| Kimi K3 is the maximum-capability open-weight challenger | Moderate | Strong publisher coding and independent general-agent evidence, plus competitive Senior SWE results; limited standardized coding reproduction and no broad Elixir evaluation. |
| GLM-5.2 is better than Kimi K3 at Elixir | Low | Ten public task families, overlapping intervals, denominator sensitivity, and a tasteful-gate discrepancy prevent this claim. |
| MiniMax M3 should not be the first Elixir default | Moderate-low | Its small Elixir slice trails while its aggregate benchmark is strong; the sample may not represent the population. |
| Qwen3.6-27B is the quality-first local candidate | Moderate | Strong within-family publisher comparison, permissive license, feasible size, but no controlled JidoCode result. |
| Qwen3.6-35B-A3B is a credible 32 GB local candidate | Moderate for operability, low for comparative quality | One concrete current practitioner report demonstrates operation and useful workflow; it is not a benchmark. |
| Repository instructions, tools, and verification materially affect Elixir outcomes | High | Benchmark methodology, JidoCode research, and diverse practitioner reports consistently identify the system rather than the model alone as the evaluation object. |

Additional limitations include:

- all current model and leaderboard facts can age quickly;
- public tasks may be contaminated or familiar despite freshness controls;
- vendor-reported scores use heterogeneous harnesses and budgets;
- Senior SWE-Bench includes model-judged quality fields;
- the ten-task Elixir slice is public, small, and concentrated in three
  repositories;
- forum participants are self-selected and report successful and failed
  workflows unevenly;
- local quantization can change tool use, reasoning, and long-context behavior;
  and
- no result in this report measures the exact JidoCode architecture or threat
  distribution.

## Final recommendation

Adopt no model from this research alone.

For the first controlled JidoCode evaluation, use GLM-5.2 as the hosted
baseline, Kimi K3 as the frontier challenger, Qwen3.6-27B as the local
quality candidate, and Qwen3.6-35B-A3B as the local throughput candidate.
Retain MiniMax M3 or DeepSeek V4 Pro as an optional hosted comparison.

Treat public benchmarks as candidate-discovery and diagnostic evidence only.
The current evidence is sufficient to prioritize the experiment and
insufficient to claim that one model is best at Elixir. The selection decision
must come from repeated, pinned, Elixir-first JidoCode trials with independent
hidden verification, blinded idiomaticity review, security outcomes, and
profile-specific cost and latency constraints [JC01].

## References

### Open-source definition and licenses

- **OS01.** Open Source Initiative,
  [Open Source AI Definition 1.0](https://opensource.org/ai/open-source-ai-definition),
  including the preferred-form-for-modification and data-information
  requirements.
- **LC01.** Moonshot AI,
  [Kimi K3 License](https://github.com/MoonshotAI/Kimi-K3/blob/main/LICENSE),
  retrieved 2026-08-19.
- **LC02.** MiniMax,
  [MiniMax Community License for M3](https://huggingface.co/MiniMaxAI/MiniMax-M3/blob/main/LICENSE),
  retrieved 2026-08-19.

### Model reports, cards, and serving sources

- **MD01.** Moonshot AI,
  [Kimi K3 repository and model card](https://github.com/MoonshotAI/Kimi-K3)
  and
  [Kimi K3 technical report](https://arxiv.org/abs/2607.24653), 2026.
- **MD02.** Z.ai,
  [GLM-5.2 model card](https://huggingface.co/zai-org/GLM-5.2), including
  license, context, publisher benchmarks, and evaluation footnotes.
- **MD03.** vLLM,
  [GLM-5.2 serving recipe](https://github.com/vllm-project/recipes/blob/main/models/zai-org/GLM-5.2.yaml),
  inspected 2026-08-19; and Z.ai,
  [GLM-5 technical report](https://arxiv.org/abs/2602.15763), 2026.
- **MD04.** MiniMax,
  [MiniMax M3 repository and model summary](https://github.com/MiniMax-AI/MiniMax-M3)
  and
  [technical report](https://arxiv.org/abs/2606.13392), 2026.
- **MD05.** DeepSeek,
  [DeepSeek V4 Pro model card](https://huggingface.co/deepseek-ai/DeepSeek-V4-Pro),
  including architecture, license, context, and publisher evaluation.
- **MD06.** Qwen,
  [Qwen3.6-27B model card](https://huggingface.co/Qwen/Qwen3.6-27B),
  including Apache-2.0 license, model dimensions, context, and publisher
  evaluation.
- **MD07.** Qwen,
  [Qwen3.6-35B-A3B model card](https://huggingface.co/Qwen/Qwen3.6-35B-A3B).
- **MD08.** Qwen,
  [Qwen3-Coder-Next model card](https://huggingface.co/Qwen/Qwen3-Coder-Next).
- **MD09.** Moonshot AI,
  [Kimi K2.7 Code model card](https://huggingface.co/moonshotai/Kimi-K2.7-Code).

### Independent analysis

- **IA01.** Artificial Analysis,
  [Kimi K3 Intelligence Index analysis](https://artificialanalysis.ai/articles/kimi-k3-achieves-3-in-the-artificial-analysis-intelligence-index-comparable-to-opus-4-8-and-gpt-5-5/),
  2026.
- **IA02.** Artificial Analysis,
  [Kimi K3 on the AA-Briefcase agentic knowledge benchmark](https://artificialanalysis.ai/articles/kimi-k3-agentic-knowledge-benchmark),
  2026.
- **IA03.** Justin Huang,
  [AutoCodeBench: When LLMs Generate Code Benchmarks](https://justinhuangai.github.io/posts/autocodebench-large-language-models-are-automatic-code-benchmark-generators/),
  methodological audit and Elixir-column analysis, 2026.

### Coding and multilingual benchmarks

- **CB01.** SWE-rebench,
  [current leaderboard](https://swe-rebench.com/), snapshot retrieved
  2026-08-19.
- **CB02.** SWE-rebench,
  [benchmark motivation, fixed-scaffold method, prompts, and repeated-run policy](https://swe-rebench.com/about).
- **CB03.** Snorkel AI,
  [Senior SWE-Bench agents leaderboard](https://senior-swe-bench.snorkel.ai/agents),
  including aggregate model results and public run data, snapshot generated
  2026-08-14 and retrieved 2026-08-19.
- **CB04.** Snorkel AI,
  [How Senior SWE-Bench works](https://senior-swe-bench.snorkel.ai/blog/2026-06-16-how-it-works),
  task construction and quality gates, 2026.
- **CB05.** Snorkel AI,
  [Senior SWE-Bench refresh](https://senior-swe-bench.snorkel.ai/blog/2026-07-30-refresh),
  three-run evaluation and reward-hacking exclusions, 2026.
- **CB06.** Bogomolov et al.,
  [SWE-rebench V2: Language-Agnostic SWE Task Collection at Scale](https://arxiv.org/abs/2602.23866),
  2026 preprint.
- **CB07.** Chou et al.,
  [AutoCodeBench: Large Language Models are Automatic Code Benchmark Generators](https://arxiv.org/abs/2508.09101),
  ICLR 2026.
- **CB08.** Tencent Hunyuan,
  [AutoCodeBenchmark repository, data, and leaderboard](https://github.com/Tencent-Hunyuan/AutoCodeBenchmark)
  and
  [ICLR 2026 paper record](https://openreview.net/forum?id=fN0MED2Idq).
- **CB09.** Chai et al.,
  [McEval: Massively Multilingual Code Evaluation](https://arxiv.org/abs/2406.07436),
  2024.

### Elixir engineering articles and practitioner evidence

- **EL01.** Jose Valim,
  [Why Elixir is the best language for AI](https://dashbit.co/blog/why-elixir-best-language-for-ai),
  Dashbit, 2026.
- **EL02.** Benjamin Thomas,
  [Benchmarking LLMs on Advent of Code 2025: Elixir](https://benjamin-thomas.github.io/posts/aoc-2025-llm-benchmark-elixir/),
  2026.
- **EL03.** Federico Alcantara,
  [Successful development with local AI setup](https://elixirforum.com/t/successful-development-with-local-ai-setup/75264),
  Elixir Forum, 2026.
- **EL04.** r/elixir,
  [AI models better suited for Elixir](https://www.reddit.com/r/elixir/comments/1u905ym/ai_models_better_suited_for_elixir/),
  2026 community discussion.
- **EL05.** r/elixir,
  [How well agentic tools produce Elixir and Phoenix code](https://www.reddit.com/r/elixir/comments/1tsu382/how_well_agentic_tools_produce_elixir_phoenix_code/),
  2026 community discussion.
- **EL06.** dmitriid,
  [A Credo plugin to clean up Ash-related LLM-isms](https://elixirforum.com/t/a-credo-plugin-to-cleanup-ash-related-llm-isms/76375),
  Elixir Forum, 2026; companion
  [`llamex` repository](https://github.com/dmitriid/llamex).

### JidoCode local sources

- **JC01.** JidoCode,
  [Coding Agent Evaluations For Development](08-coding-agent-evaluations-for-development.md).
- **JC02.** JidoCode,
  [Prompt Improvement And Evaluation](09-prompt-improvement-and-evaluation.md).
- **JC03.** JidoCode, [`AGENTS.md`](../../AGENTS.md), inspected at
  `33f7677512cd89202091c3ac7f26ddd18d01b646`.
