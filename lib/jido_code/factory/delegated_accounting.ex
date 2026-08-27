defmodule JidoCode.Factory.DelegatedAccounting do
  @moduledoc "Honest outer accounting for opaque delegated coding turns."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.DelegatedCheckpoint
  alias JidoCode.Knowledge

  @effect_kinds ~w[codex_run credential_release registered_check checkpoint_capture candidate_capture verifier]a
  @observation_classes ~w[lifecycle usage changed_paths check_request terminal workspace patch tree artifact omission]a
  @outcomes ~w[succeeded failed cancelled timed_out ambiguous]a
  @unavailable_dimensions ~w[internal_prompts hidden_reasoning provider_context internal_tool_mediation provider_private_state]a
  @forbidden_keys ~w[prompt prompts raw_prompt raw_prompts transcript transcripts reasoning hidden_reasoning context provider_context output raw_output credential credentials secret secrets token tokens password authorization environment argv session provider_session]a
  @digest ~r/^[a-f0-9]{64}$/

  @enforce_keys [
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :profile_digest,
    :run_iri,
    :delegated_input_manifest_digest,
    :policy_revision,
    :started_at,
    :effects,
    :observations,
    :checkpoint_iris,
    :unavailable_dimensions
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         true <- Enum.all?(digest_fields(), &digest?(attributes[&1])),
         %DateTime{} = started_at <- attributes[:started_at] do
      {:ok,
       %__MODULE__{
         attempt_iri: attributes.attempt_iri,
         lease_iri: attributes.lease_iri,
         fencing_token: fence,
         profile_digest: attributes.profile_digest,
         run_iri: attributes.run_iri,
         delegated_input_manifest_digest: attributes.delegated_input_manifest_digest,
         policy_revision: attributes.policy_revision,
         started_at: DateTime.truncate(started_at, :microsecond),
         effects: %{},
         observations: [],
         checkpoint_iris: [],
         unavailable_dimensions: @unavailable_dimensions
       }}
    else
      _invalid -> invalid(:delegated_accounting)
    end
  rescue
    _error -> invalid(:delegated_accounting)
  end

  def new(_attributes), do: invalid(:delegated_accounting)

  @spec start_effect(t(), map()) :: {:ok, t(), map()} | {:error, AdapterError.t()}
  def start_effect(%__MODULE__{} = accounting, attributes) when is_map(attributes) do
    with :ok <- correlation(accounting, attributes),
         kind when kind in @effect_kinds <- attributes[:kind],
         %DateTime{} = occurred_at <- attributes[:occurred_at],
         identity when is_binary(identity) and byte_size(identity) in 1..256 <-
           attributes[:effect_identity],
         {:ok, effect_iri} <- effect_iri(accounting, kind, identity),
         false <- Map.has_key?(accounting.effects, effect_iri) do
      receipt = %{
        effect_iri: effect_iri,
        effect_identity_digest: digest(identity),
        kind: kind,
        invocation: :committed_before_effect,
        status: :started,
        occurred_at: DateTime.truncate(occurred_at, :microsecond)
      }

      {:ok, %{accounting | effects: Map.put(accounting.effects, effect_iri, receipt)}, receipt}
    else
      true -> conflict(:delegated_accounting_effect_start)
      _invalid -> invalid(:delegated_accounting_effect_start)
    end
  rescue
    _error -> invalid(:delegated_accounting_effect_start)
  end

  def start_effect(_accounting, _attributes), do: invalid(:delegated_accounting_effect_start)

  @spec finish_effect(t(), String.t(), map()) ::
          {:ok, t(), map()} | {:error, AdapterError.t()}
  def finish_effect(%__MODULE__{} = accounting, effect_iri, attributes)
      when is_binary(effect_iri) and is_map(attributes) do
    with {:ok, %{status: :started} = started} <- Map.fetch(accounting.effects, effect_iri),
         :ok <- correlation(accounting, attributes),
         outcome when outcome in @outcomes <- attributes[:outcome],
         %DateTime{} = occurred_at <- attributes[:occurred_at],
         true <- DateTime.compare(occurred_at, started.occurred_at) in [:gt, :eq],
         observation when is_map(observation) <- Map.get(attributes, :observation, %{}),
         :ok <- bounded_safe(observation) do
      terminal =
        started
        |> Map.merge(%{
          status: :terminal,
          outcome: outcome,
          lifecycle_outcome: lifecycle_outcome(outcome),
          effect_classification: effect_classification(outcome),
          observation: observation,
          occurred_at: DateTime.truncate(occurred_at, :microsecond)
        })

      {:ok, %{accounting | effects: Map.put(accounting.effects, effect_iri, terminal)}, terminal}
    else
      :error -> unavailable(:delegated_accounting_effect_outcome)
      {:ok, _terminal} -> conflict(:delegated_accounting_effect_outcome)
      _invalid -> invalid(:delegated_accounting_effect_outcome)
    end
  rescue
    _error -> invalid(:delegated_accounting_effect_outcome)
  end

  def finish_effect(_accounting, _effect_iri, _attributes),
    do: invalid(:delegated_accounting_effect_outcome)

  @spec observe(t(), atom(), term(), DateTime.t()) :: {:ok, t()} | {:error, AdapterError.t()}
  def observe(%__MODULE__{} = accounting, class, value, %DateTime{} = observed_at)
      when class in @observation_classes do
    with :ok <- bounded_safe(value) do
      observation = %{
        class: class,
        value: value,
        observed_at: DateTime.truncate(observed_at, :microsecond),
        authority: :controller_observation
      }

      {:ok, %{accounting | observations: accounting.observations ++ [observation]}}
    else
      _invalid -> invalid(:delegated_accounting_observation)
    end
  end

  def observe(%__MODULE__{}, _class, _value, _observed_at),
    do: invalid(:delegated_accounting_observation)

  @spec attach_checkpoint(t(), DelegatedCheckpoint.t()) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def attach_checkpoint(%__MODULE__{} = accounting, %DelegatedCheckpoint{} = checkpoint) do
    if checkpoint.attempt_iri == accounting.attempt_iri and
         checkpoint.lease_iri == accounting.lease_iri and
         checkpoint.fencing_token == accounting.fencing_token and
         Knowledge.validate_resource_identity(checkpoint.checkpoint_iri) == :ok do
      {:ok,
       %{
         accounting
         | checkpoint_iris:
             (accounting.checkpoint_iris ++ [checkpoint.checkpoint_iri])
             |> Enum.uniq()
             |> Enum.sort()
       }}
    else
      invalid(:delegated_accounting_checkpoint)
    end
  end

  def attach_checkpoint(%__MODULE__{}, _checkpoint),
    do: invalid(:delegated_accounting_checkpoint)

  @spec close(t(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def close(%__MODULE__{} = accounting, terminal) when is_map(terminal) do
    with true <- map_size(accounting.effects) > 0,
         true <-
           Enum.all?(accounting.effects, fn {_iri, effect} -> effect.status == :terminal end),
         :ok <- correlation(accounting, terminal),
         outcome when outcome in @outcomes <- terminal[:outcome],
         %DateTime{} = completed_at <- terminal[:occurred_at],
         true <- DateTime.compare(completed_at, accounting.started_at) in [:gt, :eq] do
      material = %{
        attempt_iri: accounting.attempt_iri,
        lease_iri: accounting.lease_iri,
        fencing_token: accounting.fencing_token,
        profile_digest: accounting.profile_digest,
        run_iri: accounting.run_iri,
        delegated_input_manifest_digest: accounting.delegated_input_manifest_digest,
        policy_revision: accounting.policy_revision,
        effects: accounting.effects |> Map.values() |> Enum.sort_by(& &1.effect_iri),
        observations: accounting.observations,
        checkpoint_iris: accounting.checkpoint_iris,
        unavailable_dimensions: accounting.unavailable_dimensions,
        accounting_scope: :outer_controller_only,
        internal_accounting_complete?: false,
        outcome: outcome,
        lifecycle_outcome: lifecycle_outcome(outcome),
        effect_classification: effect_classification(outcome)
      }

      {:ok,
       Map.merge(material, %{
         accounting_digest: digest(material),
         completed_at: DateTime.truncate(completed_at, :microsecond)
       })}
    else
      false -> conflict(:delegated_accounting_close)
      _invalid -> invalid(:delegated_accounting_close)
    end
  rescue
    _error -> invalid(:delegated_accounting_close)
  end

  def close(_accounting, _terminal), do: invalid(:delegated_accounting_close)

  defp resources(attributes) do
    if Enum.all?(~w[attempt_iri lease_iri run_iri]a, fn field ->
         Knowledge.validate_resource_identity(attributes[field]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp digest_fields,
    do: ~w[profile_digest delegated_input_manifest_digest policy_revision]a

  defp correlation(accounting, attributes) do
    if attributes[:attempt_iri] == accounting.attempt_iri and
         attributes[:lease_iri] == accounting.lease_iri and
         attributes[:fencing_token] == accounting.fencing_token,
       do: :ok,
       else: :error
  end

  defp effect_iri(accounting, kind, identity) do
    Knowledge.deterministic_resource_identity(
      :tool_invocation,
      Enum.join([accounting.attempt_iri, accounting.fencing_token, kind, identity], "\n")
    )
  end

  defp bounded_safe(value) do
    encoded = :erlang.term_to_binary(value, [:deterministic])

    if byte_size(encoded) <= 65_536 and not forbidden?(value) and not secret?(value),
      do: :ok,
      else: :error
  end

  defp forbidden?(%_{} = value), do: value |> Map.from_struct() |> forbidden?()

  defp forbidden?(value) when is_map(value) do
    Enum.any?(value, fn {key, item} -> forbidden_key?(key) or forbidden?(item) end)
  end

  defp forbidden?(value) when is_list(value), do: Enum.any?(value, &forbidden?/1)
  defp forbidden?(_value), do: false

  defp forbidden_key?(key) when is_atom(key), do: key in @forbidden_keys

  defp forbidden_key?(key) when is_binary(key) do
    normalized = String.downcase(key)
    Enum.any?(@forbidden_keys, &(normalized == Atom.to_string(&1)))
  end

  defp forbidden_key?(_key), do: false

  defp secret?(%_{} = value), do: value |> Map.from_struct() |> secret?()

  defp secret?(value) when is_map(value),
    do: Enum.any?(value, fn {key, item} -> secret?(key) or secret?(item) end)

  defp secret?(value) when is_list(value), do: Enum.any?(value, &secret?/1)

  defp secret?(value) when is_binary(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp secret?(_value), do: false

  defp lifecycle_outcome(:timed_out), do: :failed
  defp lifecycle_outcome(:ambiguous), do: :unchanged_pending_reconciliation
  defp lifecycle_outcome(outcome), do: outcome

  defp effect_classification(:ambiguous), do: :ambiguous
  defp effect_classification(_outcome), do: :attributable

  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
