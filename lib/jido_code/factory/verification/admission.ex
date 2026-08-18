defmodule JidoCode.Factory.Verification.Admission do
  @moduledoc """
  Immutable admission contract for verification of one closed execution run.

  The caller must project a committed `FinalizeExecutionRun` receipt from the
  accepted run graph. Admission binds that receipt to every source, policy,
  artifact, authority, and fencing input used by a later verifier. It does not
  perform verification and cannot express acceptance.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @enforce_keys [
    :finalization_receipt_iri,
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :run_graph_iri,
    :run_graph_revision,
    :terminal_sequence,
    :completeness,
    :missing_classes,
    :accepted_reference_sets,
    :source_graph_revisions,
    :control_graph_iri,
    :control_graph_revision,
    :base_commit,
    :base_snapshot_digest,
    :candidate_artifacts,
    :patch_digest,
    :verification_environment_digest,
    :policy_revision,
    :rubric_revision,
    :evaluator_iri,
    :evaluator_capability_iri,
    :execution_actor_iri,
    :policy_verifiable_missing_classes,
    :assessment_availability,
    :input_digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @digest ~r/^(?:sha256:)?[a-f0-9]{64}$/
  @commit ~r/^[a-f0-9]{40}(?:[a-f0-9]{24})?$/
  @media_type ~r|^[a-z0-9][a-z0-9!#$&^_.+-]*/[a-z0-9][a-z0-9!#$&^_.+-]*$|
  @max_reference_sets 24
  @max_references 500
  @max_artifacts 100
  @digest_fields [:base_snapshot_digest, :patch_digest, :verification_environment_digest]
  @contract_version "1.0.0"

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec admit(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def admit(attributes) when is_map(attributes) do
    with {:ok, receipt} <- finalization_receipt(attributes[:finalization_receipt]),
         :ok <- exact_receipt?(receipt, attributes),
         :ok <- resources(attributes, [:attempt_iri, :lease_iri, :evaluator_iri]),
         :ok <- resources(attributes, [:evaluator_capability_iri, :execution_actor_iri]),
         :ok <- graph(attributes[:run_graph_iri], :run_attempt),
         :ok <- graph(attributes[:control_graph_iri], :repository_control),
         {:ok, source_revisions} <- graph_revisions(attributes[:source_graph_revisions]),
         true <- positive_integer?(attributes[:run_graph_revision]),
         true <- positive_integer?(attributes[:control_graph_revision]),
         true <- non_negative_integer?(attributes[:terminal_sequence]),
         true <- positive_integer?(attributes[:fencing_token]),
         completeness when completeness in [:complete, :incomplete] <- attributes[:completeness],
         {:ok, missing_classes} <- classes(attributes[:missing_classes]),
         :ok <- completeness?(completeness, missing_classes),
         {:ok, accepted_references} <- reference_sets(attributes[:accepted_reference_sets]),
         {:ok, artifacts} <- artifacts(attributes[:candidate_artifacts]),
         true <- valid_commit?(attributes[:base_commit]),
         :ok <- digests(attributes, @digest_fields),
         {:ok, policy_missing} <- classes(attributes[:policy_verifiable_missing_classes]),
         true <- text?(attributes[:policy_revision], 256),
         true <- text?(attributes[:rubric_revision], 256),
         true <- attributes[:evaluator_iri] != attributes[:execution_actor_iri],
         assessment <- assessment_availability(completeness, missing_classes, policy_missing),
         normalized <-
           normalized(
             attributes,
             receipt,
             source_revisions,
             accepted_references,
             artifacts,
             missing_classes,
             policy_missing,
             assessment
           ) do
      {:ok, struct!(__MODULE__, Map.put(normalized, :input_digest, digest(normalized)))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:verification_admission)
    end
  rescue
    _error -> invalid(:verification_admission)
  end

  def admit(_attributes), do: invalid(:verification_admission)

  @spec accepting_evidence?(t()) :: boolean()
  def accepting_evidence?(%__MODULE__{completeness: :complete}), do: true
  def accepting_evidence?(%__MODULE__{}), do: false

  @spec assessment_availability(t()) :: :available | :inconclusive | :unavailable
  def assessment_availability(%__MODULE__{assessment_availability: availability}),
    do: availability

  defp finalization_receipt(
         %{
           iri: iri,
           command_type: "FinalizeExecutionRun",
           outcome: :committed,
           attempt_iri: attempt_iri,
           run_graph_iri: run_graph_iri,
           run_graph_revision: revision,
           terminal_sequence: sequence,
           completeness: completeness,
           accepted_reference_sets: references
         } = receipt
       ) do
    with :ok <- resources(%{iri: iri, attempt_iri: attempt_iri}, [:iri, :attempt_iri]),
         :ok <- graph(run_graph_iri, :run_attempt),
         true <- positive_integer?(revision),
         true <- non_negative_integer?(sequence),
         true <- completeness in [:complete, :incomplete],
         {:ok, normalized_references} <- reference_sets(references) do
      {:ok, Map.put(receipt, :accepted_reference_sets, normalized_references)}
    else
      _invalid -> invalid(:finalization_receipt)
    end
  end

  defp finalization_receipt(_receipt), do: invalid(:finalization_receipt)

  defp exact_receipt?(receipt, attributes) do
    expected = %{
      attempt_iri: attributes[:attempt_iri],
      run_graph_iri: attributes[:run_graph_iri],
      run_graph_revision: attributes[:run_graph_revision],
      terminal_sequence: attributes[:terminal_sequence],
      completeness: attributes[:completeness],
      accepted_reference_sets: attributes[:accepted_reference_sets]
    }

    actual = Map.take(receipt, Map.keys(expected))

    with {:ok, references} <- reference_sets(expected.accepted_reference_sets),
         true <- actual == %{expected | accepted_reference_sets: references} do
      :ok
    else
      _invalid -> invalid(:finalization_receipt_mismatch)
    end
  end

  defp normalized(
         attributes,
         receipt,
         source_revisions,
         references,
         artifacts,
         missing_classes,
         policy_missing,
         assessment
       ) do
    attributes
    |> Map.take(@enforce_keys)
    |> Map.put(:finalization_receipt_iri, receipt.iri)
    |> Map.put(:source_graph_revisions, source_revisions)
    |> Map.put(:accepted_reference_sets, references)
    |> Map.put(:candidate_artifacts, artifacts)
    |> Map.put(:missing_classes, missing_classes)
    |> Map.put(:policy_verifiable_missing_classes, policy_missing)
    |> Map.put(:assessment_availability, assessment)
  end

  defp assessment_availability(:complete, _missing, _policy_missing), do: :available

  defp assessment_availability(:incomplete, missing, policy_missing) do
    if MapSet.subset?(MapSet.new(missing), MapSet.new(policy_missing)),
      do: :inconclusive,
      else: :unavailable
  end

  defp graph(iri, family) do
    case Knowledge.validate_graph_identity(iri) do
      {:ok, ^family} -> :ok
      _invalid -> invalid(:verification_graph_identity)
    end
  end

  defp graph_revisions(revisions)
       when is_map(revisions) and map_size(revisions) in 1..20 do
    if Enum.all?(revisions, fn {graph_iri, revision} ->
         match?({:ok, :source_revision}, Knowledge.validate_graph_identity(graph_iri)) and
           positive_integer?(revision)
       end) do
      {:ok, revisions}
    else
      invalid(:verification_source_revisions)
    end
  end

  defp graph_revisions(_revisions), do: invalid(:verification_source_revisions)

  defp reference_sets(sets)
       when is_map(sets) and map_size(sets) in 1..@max_reference_sets do
    decoded =
      Enum.reduce_while(sets, {:ok, %{}}, fn
        {class, values}, {:ok, acc}
        when is_atom(class) and is_list(values) and length(values) <= @max_references ->
          values = values |> Enum.uniq() |> Enum.sort()

          if Enum.all?(values, &(Knowledge.validate_resource_identity(&1) == :ok)) do
            {:cont, {:ok, Map.put(acc, class, values)}}
          else
            {:halt, invalid(:verification_reference_sets)}
          end

        _invalid, _acc ->
          {:halt, invalid(:verification_reference_sets)}
      end)

    case decoded do
      {:ok, values} -> {:ok, values}
      error -> error
    end
  end

  defp reference_sets(_sets), do: invalid(:verification_reference_sets)

  defp artifacts(values)
       when is_list(values) and values != [] and length(values) <= @max_artifacts do
    decoded = Enum.map(values, &artifact/1)

    if Enum.all?(decoded, &match?({:ok, _artifact}, &1)) do
      artifacts = decoded |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.iri)

      if artifacts |> Enum.map(& &1.iri) |> Enum.uniq() |> length() == length(artifacts),
        do: {:ok, artifacts},
        else: invalid(:verification_artifacts)
    else
      invalid(:verification_artifacts)
    end
  end

  defp artifacts(_values), do: invalid(:verification_artifacts)

  defp artifact(%{iri: iri, digest: digest, media_type: media_type, byte_count: byte_count}) do
    with :ok <- resources(%{iri: iri}, [:iri]),
         true <- is_binary(digest) and Regex.match?(@digest, digest),
         true <- is_binary(media_type) and Regex.match?(@media_type, media_type),
         true <- is_integer(byte_count) and byte_count >= 0 do
      {:ok, %{iri: iri, digest: digest, media_type: media_type, byte_count: byte_count}}
    else
      _invalid -> invalid(:verification_artifact)
    end
  end

  defp artifact(_artifact), do: invalid(:verification_artifact)

  defp classes(values) when is_list(values) and length(values) <= 32 do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &is_atom/1), do: {:ok, values}, else: invalid(:verification_classes)
  end

  defp classes(_values), do: invalid(:verification_classes)

  defp completeness?(:complete, []), do: :ok
  defp completeness?(:incomplete, [_first | _rest]), do: :ok
  defp completeness?(_completeness, _missing), do: invalid(:verification_completeness)

  defp resources(attributes, fields) do
    if Enum.all?(fields, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid(:verification_resource_identity)
  end

  defp digests(attributes, fields) do
    if Enum.all?(fields, fn field ->
         value = attributes[field]
         is_binary(value) and Regex.match?(@digest, value)
       end),
       do: :ok,
       else: invalid(:verification_digest)
  end

  defp valid_commit?(value), do: is_binary(value) and Regex.match?(@commit, value)
  defp positive_integer?(value), do: is_integer(value) and value > 0
  defp non_negative_integer?(value), do: is_integer(value) and value >= 0

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
