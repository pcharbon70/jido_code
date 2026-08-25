defmodule JidoCode.Factory.ManagedCoding.RecoveryRecord do
  @moduledoc "Graph evidence and immutable pins required to reconstruct one managed attempt."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.LifecycleEvent

  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys ~w[attempt_iri tenant_iri repository_iri task_iri actor_iri old_fencing_token lifecycle_events strategy_revision profile_iri snapshot_iri policy_revision toolchain_revision reconstruction_watermark invocations budget_use artifact_iris artifact_digests candidate terminal_fact_iri evidence_complete schema_version]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <-
           resources(
             attributes,
             ~w[attempt_iri tenant_iri repository_iri task_iri actor_iri profile_iri snapshot_iri]a
           ),
         fence when is_integer(fence) and fence > 0 <- attributes[:old_fencing_token],
         [_ | _] = events <- attributes[:lifecycle_events],
         true <- Enum.all?(events, &match?(%LifecycleEvent{}, &1)),
         :ok <- digests(attributes),
         :ok <- watermark(attributes[:reconstruction_watermark]),
         :ok <- invocations(attributes[:invocations]),
         :ok <- budget(attributes[:budget_use]),
         :ok <- artifact_evidence(attributes[:artifact_iris], attributes[:artifact_digests]),
         :ok <- candidate(attributes[:candidate]),
         :ok <- optional_resource(attributes[:terminal_fact_iri]),
         complete when is_boolean(complete) <- attributes[:evidence_complete],
         version when is_integer(version) and version > 0 <- attributes[:schema_version] do
      {:ok, struct!(__MODULE__, Map.take(attributes, @enforce_keys))}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  defp resources(attributes, fields) do
    if Enum.all?(fields, &(Identity.validate_resource(attributes[&1]) == :ok)),
      do: :ok,
      else: :error
  end

  defp digests(attributes) do
    if Enum.all?(~w[strategy_revision policy_revision toolchain_revision]a, fn field ->
         valid_digest?(attributes[field])
       end),
       do: :ok,
       else: :error
  end

  defp watermark(%{sequence: sequence, event_iri: event_iri})
       when is_integer(sequence) and sequence >= 0,
       do: Identity.validate_resource(event_iri)

  defp watermark(_watermark), do: :error

  defp invocations(invocations) when is_list(invocations) and length(invocations) <= 256 do
    valid? =
      Enum.all?(invocations, fn invocation ->
        is_map(invocation) and
          Identity.validate_resource(invocation[:invocation_iri]) == :ok and
          invocation[:status] in [:intent, :completed, :ambiguous] and
          optional_resource(invocation[:outcome_iri]) == :ok
      end)

    if valid?, do: :ok, else: :error
  end

  defp invocations(_invocations), do: :error

  defp budget(value) when is_map(value) and map_size(value) <= 32 do
    if Enum.all?(value, fn {dimension, used} ->
         is_atom(dimension) and is_integer(used) and used >= 0
       end),
       do: :ok,
       else: :error
  end

  defp budget(_value), do: :error

  defp artifact_evidence(iris, digests)
       when is_list(iris) and is_map(digests) and length(iris) <= 256 do
    unique = Enum.uniq(iris)

    if length(unique) == length(iris) and Enum.sort(Map.keys(digests)) == Enum.sort(iris) and
         Enum.all?(iris, &(Identity.validate_resource(&1) == :ok)) and
         Enum.all?(digests, fn {_iri, digest} -> valid_digest?(digest) end),
       do: :ok,
       else: :error
  end

  defp artifact_evidence(_iris, _digests), do: :error

  defp candidate(nil), do: :ok

  defp candidate(%{candidate_iri: iri, digest: digest}) do
    with :ok <- Identity.validate_resource(iri), true <- valid_digest?(digest), do: :ok
  end

  defp candidate(_candidate), do: :error

  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: Identity.validate_resource(value)

  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp invalid, do: {:error, AdapterError.new(:corrupt, :managed_coding_recovery_record)}
end
