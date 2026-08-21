defmodule JidoCode.Knowledge.Memory.ProcedureTransition do
  @moduledoc "Immutable lifecycle transition for a procedure revision."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :procedure_iri,
    :prior_state,
    :next_state,
    :revision,
    :expected_predecessor,
    :actor_iri,
    :cause_iri,
    :reason,
    :recorded_at
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
  @states ~w[candidate validated stale invalidated superseded]a
  @edges %{
    candidate: ~w[validated stale invalidated superseded]a,
    validated: ~w[stale invalidated superseded]a,
    stale: ~w[validated invalidated superseded]a,
    invalidated: [],
    superseded: []
  }
  @revision "1.0.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  def revision, do: @revision
  def states, do: @states

  def new(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:procedure_iri]),
         true <- edge?(attributes),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         :ok <- ResourceIdentity.validate(attributes[:cause_iri]),
         reason when is_binary(reason) and byte_size(reason) in 1..512 <- attributes[:reason],
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :procedure_transition,
             :erlang.term_to_binary(attributes, [:deterministic])
           ) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(attributes, %{
           iri: iri,
           recorded_at: DateTime.truncate(recorded_at, :microsecond)
         })
       )}
    else
      _invalid -> {:error, Error.new(:invalid_input, :procedure_transition)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :procedure_transition)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :procedure_transition)}

  def resolve([%__MODULE__{} | _] = transitions) do
    ordered = Enum.sort_by(transitions, & &1.revision)
    first = List.first(ordered)

    valid =
      first.revision == 0 and first.prior_state == nil and
        Enum.reduce_while(Enum.drop(ordered, 1), first, fn item, prior ->
          if item.procedure_iri == prior.procedure_iri and item.revision == prior.revision + 1 and
               item.prior_state == prior.next_state and item.expected_predecessor == prior.iri,
             do: {:cont, item},
             else: {:halt, false}
        end) != false

    if valid do
      endpoint = List.last(ordered)

      {:ok,
       %{
         state: endpoint.next_state,
         revision: endpoint.revision,
         transition_iri: endpoint.iri,
         history: ordered
       }}
    else
      {:error, Error.new(:invalid_input, :procedure_transition_chain)}
    end
  end

  def resolve(_), do: {:error, Error.new(:invalid_input, :procedure_transition_chain)}

  def statements(item) do
    [
      {item.iri, @rdf_type, RDF.iri(@jf <> "ProcedureTransition")},
      {item.iri, @jf <> "transitionSubject", RDF.iri(item.procedure_iri)},
      {item.iri, @jf <> "nextState", state(item.next_state)},
      {item.iri, @jf <> "subjectRevision", RDF.XSD.NonNegativeInteger.new(item.revision)},
      {item.iri, @prov <> "wasAssociatedWith", RDF.iri(item.actor_iri)},
      {item.iri, @jf <> "cause", RDF.iri(item.cause_iri)},
      {item.iri, @jf <> "reason", RDF.XSD.String.new(item.reason)},
      {item.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(item.recorded_at)}
    ] ++
      if(item.prior_state,
        do: [
          {item.iri, @jf <> "priorState", state(item.prior_state)},
          {item.iri, @jf <> "expectedPredecessor", RDF.iri(item.expected_predecessor)}
        ],
        else: []
      )
  end

  defp edge?(%{revision: 0, prior_state: nil, next_state: :candidate, expected_predecessor: nil}),
    do: true

  defp edge?(attributes) do
    is_integer(attributes[:revision]) and attributes.revision > 0 and
      attributes[:prior_state] in @states and
      attributes[:next_state] in Map.get(@edges, attributes.prior_state, []) and
      ResourceIdentity.validate(attributes[:expected_predecessor]) == :ok
  end

  defp state(value), do: RDF.iri(@concept <> "Procedure" <> Macro.camelize(to_string(value)))
end
