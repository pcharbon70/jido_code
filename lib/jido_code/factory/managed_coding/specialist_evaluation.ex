defmodule JidoCode.Factory.ManagedCoding.SpecialistEvaluation do
  @moduledoc """
  Reproducible comparison of a minimal specialist topology with the qualified
  Phase 6 single-agent baseline.

  Specialist output remains a proposal. Host arbitration can select evidence
  for the candidate owner, but cannot verify, accept, publish, or merge it.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity

  @roles ~w[investigator coder reviewer]
  @role_keys ~w[role inputs outputs tools context_limit budget termination unavailable_authorities]a
  @budget_keys ~w[messages tokens cost_microunits timeout_ms]a
  @threshold_keys ~w[min_correctness_delta min_abstention_delta min_recovery_delta max_unsafe_delta max_regression_delta max_latency_ratio max_token_ratio max_cost_ratio max_operator_burden_ratio]a
  @higher_metrics ~w[correctness abstention recovery]a
  @lower_metrics ~w[unsafe_behavior regressions latency_ms tokens cost_microunits operator_burden_minutes]a
  @trial_keys ~w[trial_id corpus_digest profile_digest variant blinded correctness abstention recovery unsafe_behavior regressions latency_ms tokens cost_microunits operator_burden_minutes]a
  @source_keys ~w[source_iri revision digest classification]a
  @evidence_keys ~w[delegation_iri attempt_iri role fence source_complete sources body body_digest]a
  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys ~w[revision baseline_profile_digest corpus_digest role_specs thresholds minimum_sample_size digest]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with revision when is_binary(revision) and byte_size(revision) in 1..128 <-
           attributes[:revision],
         true <- valid_digest?(attributes[:baseline_profile_digest]),
         true <- valid_digest?(attributes[:corpus_digest]),
         {:ok, role_specs} <- role_specs(attributes[:role_specs]),
         :ok <- thresholds(attributes[:thresholds]),
         sample when is_integer(sample) and sample in 2..10_000 <-
           attributes[:minimum_sample_size] do
      material = %{
        revision: revision,
        baseline_profile_digest: attributes.baseline_profile_digest,
        corpus_digest: attributes.corpus_digest,
        role_specs: role_specs,
        thresholds: attributes.thresholds,
        minimum_sample_size: sample
      }

      {:ok, struct!(__MODULE__, Map.put(material, :digest, digest(material)))}
    else
      _invalid -> invalid(:managed_coding_specialist_evaluation)
    end
  rescue
    _error -> invalid(:managed_coding_specialist_evaluation)
  end

  def new(_attributes), do: invalid(:managed_coding_specialist_evaluation)

  @spec evidence_packet(map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def evidence_packet(attributes) when is_map(attributes) do
    with true <- exact_keys?(attributes, @evidence_keys),
         :ok <- Identity.validate_resource(attributes[:delegation_iri]),
         :ok <- Identity.validate_resource(attributes[:attempt_iri]),
         true <- attributes[:role] in @roles,
         fence when is_integer(fence) and fence > 0 <- attributes[:fence],
         true <- attributes[:source_complete] == true,
         {:ok, sources} <- sources(attributes[:sources]),
         body when is_binary(body) and byte_size(body) in 1..65_536 <- attributes[:body],
         true <- valid_digest?(attributes[:body_digest]),
         true <- attributes[:body_digest] == sha256(body) do
      material = %{
        delegation_iri: attributes.delegation_iri,
        attempt_iri: attributes.attempt_iri,
        role: attributes.role,
        fence: fence,
        source_complete: true,
        sources: sources,
        body_digest: attributes.body_digest
      }

      {:ok,
       material
       |> Map.put(:packet_digest, digest(material))
       |> Map.put(:body, body)}
    else
      _invalid -> invalid(:managed_coding_specialist_evidence)
    end
  rescue
    _error -> invalid(:managed_coding_specialist_evidence)
  end

  def evidence_packet(_attributes), do: invalid(:managed_coding_specialist_evidence)

  @spec compile_handoff(map(), String.t(), pos_integer()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def compile_handoff(packet, recipient_role, context_limit)
      when is_map(packet) and recipient_role in @roles and is_integer(context_limit) and
             context_limit > 0 do
    with :ok <- valid_evidence_packet(packet),
         true <- byte_size(packet[:body]) <= context_limit,
         true <- recipient_role != packet[:role] do
      manifest = %{
        recipient_role: recipient_role,
        evidence_packet_digest: packet.packet_digest,
        source_digests: Enum.map(packet.sources, & &1.digest),
        body_digest: packet.body_digest,
        transcript_included: false,
        process_memory_included: false
      }

      {:ok, Map.put(manifest, :context_digest, digest(manifest))}
    else
      _invalid -> invalid(:managed_coding_specialist_handoff)
    end
  end

  def compile_handoff(_packet, _recipient_role, _limit),
    do: invalid(:managed_coding_specialist_handoff)

  @spec arbitrate(String.t(), [map()]) :: {:ok, map()} | {:error, AdapterError.t()}
  def arbitrate("coder", proposals) when is_list(proposals) and proposals != [] do
    valid =
      Enum.all?(proposals, fn proposal ->
        exact_keys?(proposal, ~w[role packet_digest severity recommendation]a) and
          proposal.role in @roles and valid_digest?(proposal.packet_digest) and
          proposal.severity in [:blocking, :major, :minor, :note] and
          is_binary(proposal.recommendation) and
          byte_size(proposal.recommendation) in 1..4_096
      end)

    if valid do
      selected =
        Enum.min_by(proposals, fn proposal ->
          {severity_order(proposal.severity), proposal.packet_digest, proposal.role}
        end)

      {:ok,
       %{
         candidate_owner: "coder",
         selected_packet_digest: selected.packet_digest,
         recommendation: selected.recommendation,
         resolution: :host_selected_revision_proposal,
         acceptance: :unavailable,
         merge: :unavailable
       }}
    else
      invalid(:managed_coding_specialist_arbitration)
    end
  end

  def arbitrate(_candidate_owner, _proposals),
    do: invalid(:managed_coding_specialist_arbitration)

  @spec compare(t(), [map()], [map()]) :: {:ok, map()} | {:error, AdapterError.t()}
  def compare(%__MODULE__{} = program, baseline_trials, topology_trials)
      when is_list(baseline_trials) and is_list(topology_trials) do
    with true <- length(baseline_trials) >= program.minimum_sample_size,
         true <- length(baseline_trials) == length(topology_trials),
         true <- Enum.all?(baseline_trials, &valid_trial?(&1, program, "single_agent")),
         true <- Enum.all?(topology_trials, &valid_trial?(&1, program, "specialists")),
         true <- paired?(baseline_trials, topology_trials) do
      baseline = summarize(baseline_trials)
      topology = summarize(topology_trials)
      deltas = deltas(baseline, topology)
      failures = failures(program.thresholds, deltas)
      decision = decision(failures)

      result = %{
        baseline_profile_digest: program.baseline_profile_digest,
        corpus_digest: program.corpus_digest,
        sample_size: length(baseline_trials),
        blinded: true,
        baseline: baseline,
        topology: topology,
        deltas: deltas,
        failures: failures,
        decision: decision,
        production_profile: "single_agent",
        specialist_profile_enabled: decision == :accept
      }

      {:ok, Map.put(result, :digest, digest(result))}
    else
      _invalid -> invalid(:managed_coding_specialist_comparison)
    end
  end

  def compare(_program, _baseline, _topology),
    do: invalid(:managed_coding_specialist_comparison)

  defp role_specs(values) when is_list(values) and values != [] and length(values) <= 3 do
    normalized = Enum.sort_by(values, & &1.role)

    valid =
      Enum.all?(normalized, fn spec ->
        exact_keys?(spec, @role_keys) and spec.role in @roles and string_list?(spec.inputs) and
          string_list?(spec.outputs) and digest_list?(spec.tools) and
          is_integer(spec.context_limit) and spec.context_limit in 1..262_144 and
          valid_role_budget?(spec.budget) and string_list?(spec.termination) and
          Enum.sort(spec.unavailable_authorities) ==
            Enum.sort(~w[acceptance graph merge policy publication topology verification])
      end) and
        normalized |> Enum.map(& &1.role) |> Enum.uniq() |> length() == length(normalized)

    if valid, do: {:ok, normalized}, else: :error
  end

  defp role_specs(_values), do: :error

  defp valid_role_budget?(budget) when is_map(budget) do
    exact_keys?(budget, @budget_keys) and
      Enum.all?(@budget_keys, &(is_integer(budget[&1]) and budget[&1] > 0))
  end

  defp valid_role_budget?(_budget), do: false

  defp thresholds(values) when is_map(values) do
    valid =
      exact_keys?(values, @threshold_keys) and
        Enum.all?(@threshold_keys, &(is_number(values[&1]) and values[&1] >= 0))

    if valid, do: :ok, else: :error
  end

  defp thresholds(_values), do: :error

  defp sources(values) when is_list(values) and values != [] and length(values) <= 128 do
    normalized = Enum.sort_by(values, & &1.source_iri)

    valid =
      Enum.all?(normalized, fn source ->
        exact_keys?(source, @source_keys) and
          Identity.validate_resource(source.source_iri) == :ok and
          valid_digest?(source.revision) and valid_digest?(source.digest) and
          source.classification in ~w[public internal confidential restricted]
      end) and
        normalized |> Enum.map(& &1.source_iri) |> Enum.uniq() |> length() == length(normalized)

    if valid, do: {:ok, normalized}, else: :error
  end

  defp sources(_values), do: :error

  defp valid_evidence_packet(packet) do
    material =
      Map.take(packet, [
        :delegation_iri,
        :attempt_iri,
        :role,
        :fence,
        :source_complete,
        :sources,
        :body_digest
      ])

    valid =
      exact_keys?(packet, [
        :delegation_iri,
        :attempt_iri,
        :role,
        :fence,
        :source_complete,
        :sources,
        :body_digest,
        :packet_digest,
        :body
      ]) and packet.source_complete == true and valid_digest?(packet.packet_digest) and
        packet.packet_digest == digest(material) and packet.body_digest == sha256(packet.body)

    if valid, do: :ok, else: :error
  rescue
    _error -> :error
  end

  defp valid_trial?(trial, program, variant) when is_map(trial) do
    exact_keys?(trial, @trial_keys) and Identity.validate_resource(trial.trial_id) == :ok and
      trial.corpus_digest == program.corpus_digest and
      trial.profile_digest == program.baseline_profile_digest and trial.variant == variant and
      trial.blinded == true and Enum.all?(@higher_metrics, &boolean_metric?(trial[&1])) and
      Enum.all?(@lower_metrics, &(is_integer(trial[&1]) and trial[&1] >= 0))
  end

  defp valid_trial?(_trial, _program, _variant), do: false

  defp boolean_metric?(value), do: is_boolean(value)

  defp paired?(baseline, topology) do
    Enum.sort(Enum.map(baseline, & &1.trial_id)) == Enum.sort(Enum.map(topology, & &1.trial_id))
  end

  defp summarize(trials) do
    higher = Map.new(@higher_metrics, &{&1, mean_boolean(trials, &1)})
    lower = Map.new(@lower_metrics, &{&1, mean_number(trials, &1)})
    Map.merge(higher, lower)
  end

  defp deltas(baseline, topology) do
    %{
      correctness: topology.correctness - baseline.correctness,
      abstention: topology.abstention - baseline.abstention,
      recovery: topology.recovery - baseline.recovery,
      unsafe_behavior: topology.unsafe_behavior - baseline.unsafe_behavior,
      regressions: topology.regressions - baseline.regressions,
      latency_ratio: ratio(topology.latency_ms, baseline.latency_ms),
      token_ratio: ratio(topology.tokens, baseline.tokens),
      cost_ratio: ratio(topology.cost_microunits, baseline.cost_microunits),
      operator_burden_ratio:
        ratio(topology.operator_burden_minutes, baseline.operator_burden_minutes)
    }
  end

  defp failures(thresholds, deltas) do
    []
    |> fail_if(deltas.correctness < thresholds.min_correctness_delta, :correctness_gain)
    |> fail_if(deltas.abstention < thresholds.min_abstention_delta, :abstention_gain)
    |> fail_if(deltas.recovery < thresholds.min_recovery_delta, :recovery_gain)
    |> fail_if(deltas.unsafe_behavior > thresholds.max_unsafe_delta, :unsafe_behavior)
    |> fail_if(deltas.regressions > thresholds.max_regression_delta, :regressions)
    |> fail_if(deltas.latency_ratio > thresholds.max_latency_ratio, :latency)
    |> fail_if(deltas.token_ratio > thresholds.max_token_ratio, :tokens)
    |> fail_if(deltas.cost_ratio > thresholds.max_cost_ratio, :cost)
    |> fail_if(
      deltas.operator_burden_ratio > thresholds.max_operator_burden_ratio,
      :operator_burden
    )
    |> Enum.reverse()
  end

  defp decision([]), do: :accept

  defp decision(failures) do
    if Enum.any?(failures, &(&1 in [:correctness_gain, :unsafe_behavior, :regressions])) do
      :reject
    else
      :restrict
    end
  end

  defp severity_order(:blocking), do: 0
  defp severity_order(:major), do: 1
  defp severity_order(:minor), do: 2
  defp severity_order(:note), do: 3
  defp fail_if(failures, true, name), do: [name | failures]
  defp fail_if(failures, false, _name), do: failures
  defp mean_boolean(trials, key), do: Enum.count(trials, & &1[key]) / length(trials)
  defp mean_number(trials, key), do: Enum.sum(Enum.map(trials, & &1[key])) / length(trials)
  defp ratio(_value, baseline) when baseline == 0, do: :infinity
  defp ratio(value, baseline), do: value / baseline

  defp string_list?(values) do
    is_list(values) and values != [] and length(values) <= 32 and
      Enum.all?(values, &(is_binary(&1) and byte_size(&1) in 1..128))
  end

  defp digest_list?(values),
    do: is_list(values) and values != [] and Enum.all?(values, &valid_digest?/1)

  defp exact_keys?(map, keys), do: Enum.sort(Map.keys(map)) == Enum.sort(keys)
  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
