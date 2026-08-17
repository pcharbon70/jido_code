defmodule JidoCode.Factory.Tool.Capability do
  @moduledoc "Lease-attenuated, non-decision capability for one attempt and fence."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Catalog
  alias JidoCode.Knowledge

  @derive {Inspect,
           only: [
             :attempt_iri,
             :lease_iri,
             :repository_iri,
             :snapshot_iri,
             :permitted_tools,
             :expires_at,
             :fencing_token,
             :idempotency_namespace
           ]}
  @enforce_keys [
    :attempt_iri,
    :lease_iri,
    :task_iri,
    :repository_iri,
    :actor_iri,
    :agent_iri,
    :profile_iri,
    :model,
    :tool_catalog_version,
    :snapshot_iri,
    :source_graph_revisions,
    :permitted_tools,
    :path_prefixes,
    :ref_iris,
    :graph_scope_iris,
    :network_destinations,
    :registered_commands,
    :data_classes,
    :resource_ceilings,
    :credential_reference_iris,
    :expires_at,
    :fencing_token,
    :idempotency_namespace,
    :policy_revision,
    :revocation_generation,
    :authority_classes
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @resource_fields ~w[
    attempt_iri lease_iri task_iri repository_iri actor_iri agent_iri profile_iri snapshot_iri
  ]a
  @data_classes ~w[public internal confidential restricted]a

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <-
           Enum.all?(
             @resource_fields,
             &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)
           ),
         model when is_binary(model) and byte_size(model) in 1..160 <- attributes[:model],
         "1.0.0" <- attributes[:tool_catalog_version],
         true <- revisions?(attributes[:source_graph_revisions]),
         true <- tools?(attributes[:permitted_tools]),
         true <- paths?(attributes[:path_prefixes]),
         true <- resources?(attributes[:ref_iris], 128),
         true <- resources?(attributes[:graph_scope_iris], 32),
         true <- text_list?(attributes[:network_destinations], 32, 256),
         true <- text_list?(attributes[:registered_commands], 32, 64),
         true <- enum_list?(attributes[:data_classes], @data_classes),
         true <- ceilings?(attributes[:resource_ceilings]),
         true <- resources?(attributes[:credential_reference_iris], 32),
         %DateTime{} = expires_at <- attributes[:expires_at],
         true <- DateTime.compare(expires_at, DateTime.utc_now()) == :gt,
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         namespace when is_binary(namespace) <- attributes[:idempotency_namespace],
         true <- Regex.match?(~r/^sha256:[a-f0-9]{64}$/, namespace),
         revision when is_integer(revision) and revision > 0 <- attributes[:policy_revision],
         generation when is_integer(generation) and generation > 0 <-
           attributes[:revocation_generation],
         [:tool_execution] <- attributes[:authority_classes] do
      {:ok,
       struct!(
         __MODULE__,
         attributes
         |> Map.take(@enforce_keys)
         |> Map.update!(:expires_at, &DateTime.truncate(&1, :microsecond))
       )}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec valid_at?(t(), DateTime.t()) :: boolean()
  def valid_at?(%__MODULE__{} = capability, %DateTime{} = at) do
    case new(Map.from_struct(capability)) do
      {:ok, _valid} -> DateTime.compare(at, capability.expires_at) == :lt
      {:error, _error} -> false
    end
  end

  def valid_at?(_capability, _at), do: false

  defp revisions?(revisions) when is_map(revisions) and map_size(revisions) in 1..32 do
    Enum.all?(revisions, fn {iri, revision} ->
      Knowledge.validate_resource_identity(iri) == :ok and is_integer(revision) and revision > 0
    end)
  end

  defp revisions?(_revisions), do: false

  defp tools?(tools) when is_list(tools) and tools != [] and length(tools) <= 32 do
    Enum.all?(tools, &(&1 in Catalog.names())) and length(tools) == length(Enum.uniq(tools))
  end

  defp tools?(_tools), do: false

  defp paths?(paths) when is_list(paths) and length(paths) <= 64 do
    Enum.all?(paths, fn path ->
      is_binary(path) and byte_size(path) in 1..512 and Path.type(path) == :relative and
        path == Path.join(Path.split(path)) and
        not Enum.any?(Path.split(path), &(&1 in [".", ".."]))
    end) and length(paths) == length(Enum.uniq(paths))
  end

  defp paths?(_paths), do: false

  defp resources?(values, maximum) when is_list(values) and length(values) <= maximum do
    Enum.all?(values, &(Knowledge.validate_resource_identity(&1) == :ok)) and
      length(values) == length(Enum.uniq(values))
  end

  defp resources?(_values, _maximum), do: false

  defp text_list?(values, count, bytes) when is_list(values) and length(values) <= count do
    Enum.all?(values, &(is_binary(&1) and byte_size(&1) in 1..bytes)) and
      length(values) == length(Enum.uniq(values))
  end

  defp text_list?(_values, _count, _bytes), do: false

  defp enum_list?(values, accepted) when is_list(values) and values != [] do
    Enum.all?(values, &(&1 in accepted)) and length(values) == length(Enum.uniq(values))
  end

  defp enum_list?(_values, _accepted), do: false

  defp ceilings?(ceilings) when is_map(ceilings) and map_size(ceilings) in 1..16 do
    Enum.all?(ceilings, fn {key, value} -> is_atom(key) and is_integer(value) and value > 0 end)
  end

  defp ceilings?(_ceilings), do: false
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :tool_capability)}
end
