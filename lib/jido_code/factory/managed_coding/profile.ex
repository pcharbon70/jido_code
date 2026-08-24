defmodule JidoCode.Factory.ManagedCoding.Profile do
  @moduledoc """
  Exact immutable configuration and authority ceiling for a managed coding runtime.

  The profile contains revisions and resource identities only. Prompt bodies,
  credentials, adapter modules, executable tool definitions, and policy logic
  remain behind their owning boundaries.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Budget
  alias JidoCode.Factory.ManagedCoding.Vocabulary
  alias JidoCode.Knowledge

  @jido_version "2.3.2"
  @digest ~r/^[a-f0-9]{64}$/
  @revision_fields ~w[strategy_revision prompt_bundle_revision context_policy_revision memory_policy_revision tool_catalog_revision adapter_set_revision sandbox_profile_revision verifier_profile_revision candidate_schema_revision]a
  @binding_fields ~w[actor_iris tenant_iris repository_iris capability_iris]a
  @enforce_keys [
                  :iri,
                  :revision,
                  :jido_version,
                  :model_access_profile_iri,
                  :budget,
                  :state,
                  :rollout_stage,
                  :task_classes
                ] ++ @revision_fields ++ @binding_fields
  defstruct @enforce_keys ++ [:supersedes_iri, :profile_digest]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Knowledge.validate_resource_identity(attributes[:iri]),
         revision when is_integer(revision) and revision > 0 <- attributes[:revision],
         @jido_version <- attributes[:jido_version],
         true <- Enum.all?(@revision_fields, &digest?(attributes[&1])),
         :ok <- Knowledge.validate_resource_identity(attributes[:model_access_profile_iri]),
         %Budget{} = budget <- attributes[:budget],
         state <- attributes[:state],
         true <- Vocabulary.valid?(:profile_state, state),
         stage <- attributes[:rollout_stage],
         true <- Vocabulary.valid?(:rollout_stage, stage),
         :ok <- coherent_state(state, stage),
         {:ok, task_classes} <- task_classes(attributes[:task_classes]),
         {:ok, bindings} <- bindings(attributes),
         :ok <- optional_resource(attributes[:supersedes_iri]) do
      values =
        attributes
        |> Map.take(@enforce_keys ++ [:supersedes_iri])
        |> Map.merge(bindings)
        |> Map.put(:task_classes, task_classes)
        |> Map.put(:budget, budget)

      {:ok, struct!(__MODULE__, Map.put(values, :profile_digest, digest(values)))}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_profile)}
    end
  rescue
    _error -> {:error, AdapterError.new(:invalid_input, :managed_coding_profile)}
  end

  def new(_attributes), do: {:error, AdapterError.new(:invalid_input, :managed_coding_profile)}

  @spec selectable?(t(), map()) :: boolean()
  def selectable?(%__MODULE__{state: :enabled, rollout_stage: stage} = profile, context)
      when stage != :disabled and is_map(context) do
    context[:task_class] in profile.task_classes and
      bound?(profile.actor_iris, context[:actor_iri]) and
      bound?(profile.tenant_iris, context[:tenant_iri]) and
      bound?(profile.repository_iris, context[:repository_iri]) and
      bound?(profile.capability_iris, context[:capability_iri])
  end

  def selectable?(%__MODULE__{}, _context), do: false

  @spec jido_version() :: String.t()
  def jido_version, do: @jido_version

  defp task_classes(values) when is_list(values) and values != [] and length(values) <= 32 do
    if Enum.all?(values, &valid_task_class?/1),
      do: {:ok, values |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp task_classes(_values), do: :error

  defp valid_task_class?(value) when is_binary(value) and byte_size(value) in 1..64//1,
    do: Regex.match?(~r/^[a-z][a-z0-9_-]*$/, value)

  defp valid_task_class?(_value), do: false

  defp bindings(attributes) do
    Enum.reduce_while(@binding_fields, {:ok, %{}}, fn field, {:ok, result} ->
      case binding_values(attributes[field]) do
        {:ok, values} -> {:cont, {:ok, Map.put(result, field, values)}}
        :error -> {:halt, :error}
      end
    end)
  end

  defp binding_values(values) when is_list(values) and values != [] and length(values) <= 64 do
    if Enum.all?(values, &(Knowledge.validate_resource_identity(&1) == :ok)),
      do: {:ok, values |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp binding_values(_values), do: :error

  defp coherent_state(:enabled, :disabled), do: :error
  defp coherent_state(state, stage) when state != :enabled and stage != :disabled, do: :error
  defp coherent_state(_state, _stage), do: :ok

  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: Knowledge.validate_resource_identity(value)
  defp bound?(bindings, value), do: is_binary(value) and value in bindings
  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp digest(values) do
    values
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
