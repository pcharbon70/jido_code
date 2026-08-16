defmodule JidoCode.Knowledge.Control.ApprovalRequest do
  @moduledoc """
  Human-approval requests bound to an immutable action digest.

  An approval request fixes exactly what a human is approving: a digest of
  the normalized action, the evidence set considered, the approver identity,
  and an expiry. Approval consumption, single-use enforcement, and pre-effect
  revalidation belong to the decision boundary; this resource only makes the
  reviewed content addressable and unforgeable.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Graph, as: ControlGraph
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :action_digest,
    :approver_iri,
    :expires_at,
    :evidence_iris
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @digest64 ~r/^[a-f0-9]{64}$/
  @max_evidence 100

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with action_digest when is_binary(action_digest) <-
           attributes[:action_digest],
         true <- Regex.match?(@digest64, action_digest),
         :ok <- ResourceIdentity.validate(attributes[:approver_iri]),
         %DateTime{} = expires_at <- attributes[:expires_at],
         {:ok, evidence_iris} <- evidence(attributes[:evidence_iris]),
         {:ok, iri} <-
           ResourceIdentity.deterministic(:approval_request, action_digest) do
      {:ok,
       %__MODULE__{
         iri: iri,
         action_digest: action_digest,
         approver_iri: attributes.approver_iri,
         expires_at: DateTime.truncate(expires_at, :microsecond),
         evidence_iris: evidence_iris
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:approval_request)
    end
  rescue
    _error -> invalid(:approval_request)
  end

  def new(_attributes), do: invalid(:approval_request)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = request) do
    [
      {request.iri, @rdf_type, RDF.iri(@jf <> "ApprovalRequest")},
      {request.iri, @jf <> "actionDigest", RDF.XSD.String.new(request.action_digest)},
      {request.iri, @jf <> "approvalApprover", RDF.iri(request.approver_iri)},
      {request.iri, @jf <> "approvalExpiresAt", RDF.XSD.DateTime.new(request.expires_at)},
      {request.iri, @prov <> "wasAttributedTo", RDF.iri(request.approver_iri)}
    ] ++
      Enum.map(request.evidence_iris, fn iri ->
        {request.iri, @jf <> "evidenceReference", RDF.iri(iri)}
      end)
  end

  @spec create_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def create_command(request, attributes, options \\ [])

  def create_command(%__MODULE__{} = request, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:control_graph_iri]

    with {:ok, :repository_control} <- GraphRegistry.identify(graph),
         true <-
           is_integer(attributes[:expected_control_revision]) and
             attributes[:expected_control_revision] >= 0,
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, request.iri <> "\ncreate"),
         {:ok, target} <-
           ControlGraph.target(
             graph,
             attributes[:expected_control_revision],
             attributes[:repository_scope_iri],
             command_iri,
             attributes[:recorded_at],
             statements(request)
           ),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope("CreateApprovalRequest", command_iri, request, attributes, graph, target),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:create_approval_request)
    end
  end

  def create_command(_request, _attributes, _options),
    do: invalid(:create_approval_request)

  defp envelope(type, command_iri, request, attributes, graph, target) do
    %{
      command_type: type,
      command_version: "1.8.0",
      command_iri: command_iri,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:repository_scope_iri],
      idempotency_key: command_iri,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: %{graph => attributes[:expected_control_revision]},
      reason: attributes[:reason],
      payload: %{changes: [target], guards: [{:subject_absent, graph, request.iri}]}
    }
  end

  defp evidence(values) when is_list(values) and length(values) <= @max_evidence do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values},
      else: invalid(:approval_request_evidence)
  rescue
    _error -> invalid(:approval_request_evidence)
  end

  defp evidence(_values), do: invalid(:approval_request_evidence)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
