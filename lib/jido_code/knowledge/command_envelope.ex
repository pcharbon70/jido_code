defmodule JidoCode.Knowledge.CommandEnvelope do
  @moduledoc """
  Validated, transient envelope for one semantic command.

  The struct is deliberately safe to inspect: idempotency material, reasons,
  and RDF payloads are omitted. Persisted command authority is reconstructed
  from RDF provenance and audit resources, never from this struct.
  """

  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Validation.ShapeCatalog

  @derive {Inspect,
           only: [
             :command_type,
             :command_version,
             :command_iri,
             :actor_iri,
             :scope_iri,
             :ontology_version,
             :shape_version,
             :issued_at
           ]}
  @enforce_keys [
    :command_type,
    :command_version,
    :command_iri,
    :principal_iri,
    :actor_iri,
    :delegated_agent_iri,
    :delegation_iri,
    :scope_iri,
    :idempotency_key,
    :correlation_iri,
    :causation_iri,
    :ontology_version,
    :shape_version,
    :expected_dataset_revision,
    :expected_graph_revisions,
    :reason,
    :issued_at,
    :payload
  ]
  defstruct @enforce_keys

  @max_idempotency_bytes 256
  @max_reason_bytes 512
  @max_payload_bytes 262_144
  @max_target_graphs 16

  @type t :: %__MODULE__{}

  @spec new(map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes, options \\ [])

  def new(attributes, options) when is_map(attributes) and is_list(options) do
    clock = Keyword.get(options, :clock)

    with true <- is_function(clock, 0),
         false <- Map.has_key?(attributes, :issued_at),
         {:ok, definition} <-
           CommandRegistry.resolve(attributes[:command_type], attributes[:command_version]),
         false <- CommandRegistry.generic_crud?(attributes[:command_type]),
         :ok <- validate_resource(attributes[:command_iri]),
         :ok <- validate_resource(attributes[:principal_iri]),
         :ok <- validate_resource(attributes[:actor_iri]),
         :ok <- validate_optional_resource(attributes[:delegated_agent_iri]),
         :ok <- validate_optional_resource(attributes[:delegation_iri]),
         :ok <- validate_delegation_pair(attributes),
         :ok <- validate_resource(attributes[:scope_iri]),
         :ok <- validate_text(attributes[:idempotency_key], @max_idempotency_bytes),
         :ok <- validate_resource(attributes[:correlation_iri]),
         :ok <- validate_resource(attributes[:causation_iri]),
         :ok <- validate_versions(attributes[:ontology_version], attributes[:shape_version]),
         {:ok, expected_dataset_revision} <- revision(attributes[:expected_dataset_revision]),
         {:ok, expected_graph_revisions} <-
           graph_revisions(attributes[:expected_graph_revisions]),
         true <- map_size(expected_graph_revisions) <= @max_target_graphs,
         :ok <- validate_text(attributes[:reason], @max_reason_bytes),
         {:ok, issued_at} <- trusted_time(clock),
         :ok <- validate_payload(attributes[:payload]) do
      {:ok,
       struct!(__MODULE__,
         command_type: definition.name,
         command_version: definition.version,
         command_iri: attributes[:command_iri],
         principal_iri: attributes[:principal_iri],
         actor_iri: attributes[:actor_iri],
         delegated_agent_iri: attributes[:delegated_agent_iri],
         delegation_iri: attributes[:delegation_iri],
         scope_iri: attributes[:scope_iri],
         idempotency_key: attributes[:idempotency_key],
         correlation_iri: attributes[:correlation_iri],
         causation_iri: attributes[:causation_iri],
         ontology_version: attributes[:ontology_version],
         shape_version: attributes[:shape_version],
         expected_dataset_revision: expected_dataset_revision,
         expected_graph_revisions: expected_graph_revisions,
         reason: attributes[:reason],
         issued_at: issued_at,
         payload: attributes[:payload]
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:command_envelope)
    end
  rescue
    _error -> invalid(:command_envelope)
  catch
    _kind, _reason -> invalid(:command_envelope)
  end

  def new(_attributes, _options), do: invalid(:command_envelope)

  @spec safe_map(t()) :: map()
  def safe_map(%__MODULE__{} = envelope) do
    %{
      command_type: envelope.command_type,
      command_version: envelope.command_version,
      command_iri: envelope.command_iri,
      actor_iri: envelope.actor_iri,
      scope_iri: envelope.scope_iri,
      ontology_version: envelope.ontology_version,
      shape_version: envelope.shape_version,
      issued_at: envelope.issued_at,
      idempotency_key: :redacted,
      reason: :redacted,
      payload: :redacted
    }
  end

  defp validate_versions(ontology, shape) when is_binary(ontology) and is_binary(shape) do
    if ShapeCatalog.known_versions?(ontology, shape), do: :ok, else: incompatible()
  end

  defp validate_versions(_ontology, _shape), do: incompatible()

  defp graph_revisions(revisions) when is_map(revisions) do
    Enum.reduce_while(revisions, {:ok, %{}}, fn {graph, value}, {:ok, acc} ->
      with true <- is_binary(graph),
           {:ok, _family} <- GraphRegistry.identify(graph),
           {:ok, normalized} <- revision(value),
           false <- Map.has_key?(acc, graph) do
        {:cont, {:ok, Map.put(acc, graph, normalized)}}
      else
        _invalid -> {:halt, invalid(:command_revisions)}
      end
    end)
  end

  defp graph_revisions(_revisions), do: invalid(:command_revisions)

  defp revision(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp revision(_value), do: invalid(:command_revisions)

  defp validate_payload(payload) when is_map(payload) do
    encoded = :erlang.term_to_binary(payload, [:deterministic])
    if byte_size(encoded) <= @max_payload_bytes, do: :ok, else: invalid(:command_payload)
  end

  defp validate_payload(_payload), do: invalid(:command_payload)

  defp trusted_time(clock) do
    case clock.() do
      %DateTime{} = time -> {:ok, DateTime.truncate(time, :microsecond)}
      _invalid -> invalid(:command_clock)
    end
  end

  defp validate_delegation_pair(attributes) do
    case {attributes[:delegated_agent_iri], attributes[:delegation_iri]} do
      {nil, nil} -> :ok
      {agent, delegation} when is_binary(agent) and is_binary(delegation) -> :ok
      _invalid -> invalid(:command_authority)
    end
  end

  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp validate_optional_resource(nil), do: :ok
  defp validate_optional_resource(value), do: validate_resource(value)

  defp validate_text(value, maximum) when is_binary(value) do
    normalized = :unicode.characters_to_nfc_binary(value)

    if value == normalized and byte_size(value) in 1..maximum and
         not Regex.match?(~r/[\x00-\x1F\x7F]/u, value),
       do: :ok,
       else: invalid(:command_text)
  end

  defp validate_text(_value, _maximum), do: invalid(:command_text)
  defp incompatible, do: {:error, Error.new(:incompatible, :command_semantic_version)}
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
