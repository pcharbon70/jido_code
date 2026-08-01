defmodule JidoCode.Knowledge.CurrentStateResolver do
  @moduledoc """
  Resolves operational state from accepted causal transition chains.

  Mutable status literals are ignored. Missing links, forks, cycles, revision
  regressions, illegal states, and ambiguous decisions fail as integrity
  conflicts.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.Transitions

  @jf "https://jido.run/ontology/factory#"
  @jfc "https://jido.run/ontology/concept/"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_associated "http://www.w3.org/ns/prov#wasAssociatedWith"
  @prov_generated_at "http://www.w3.org/ns/prov#generatedAtTime"
  @state_transition @jf <> "StateTransition"
  @state_by_iri %{
    (@jfc <> "Proposed") => :proposed,
    (@jfc <> "Eligible") => :eligible,
    (@jfc <> "Leased") => :leased,
    (@jfc <> "Running") => :running,
    (@jfc <> "Verifying") => :verifying,
    (@jfc <> "Satisfied") => :satisfied,
    (@jfc <> "Failed") => :failed,
    (@jfc <> "Cancelled") => :cancelled,
    (@jfc <> "Superseded") => :superseded
  }
  @max_transitions 10_000

  @spec resolve([map()], non_neg_integer()) :: {:ok, map()} | {:error, Error.t()}
  def resolve(transitions, graph_revision)
      when is_list(transitions) and length(transitions) <= @max_transitions and
             is_integer(graph_revision) and graph_revision >= 0 do
    with {:ok, chain} <- Transitions.validate_chain(transitions),
         endpoint when is_map(endpoint) <- List.last(chain.accepted) do
      {:ok,
       %{
         subject_iri: chain.subject,
         current_state: chain.current_state,
         endpoint_transition_iri: chain.current_transition,
         chain_revision: chain.current_revision,
         actor_iri: endpoint.actor,
         cause_iri: endpoint.cause,
         evaluated_graph_revision: graph_revision,
         retained_transitions: length(chain.retained)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> conflict()
    end
  rescue
    _error -> conflict()
  end

  def resolve(_transitions, _graph_revision), do: conflict()

  @spec resolve_dataset(RDF.Dataset.t(), String.t(), String.t(), non_neg_integer()) ::
          {:ok, map()} | {:error, Error.t()}
  def resolve_dataset(%RDF.Dataset{} = dataset, graph_iri, subject_iri, graph_revision) do
    with :ok <- ResourceIdentity.validate(subject_iri),
         true <- is_binary(graph_iri) and RDF.IRI.valid?(graph_iri),
         {:ok, transitions} <- decode(dataset, graph_iri, subject_iri) do
      resolve(transitions, graph_revision)
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> conflict()
    end
  end

  def resolve_dataset(_dataset, _graph, _subject, _revision), do: conflict()

  defp decode(dataset, graph_iri, subject_iri) do
    quads =
      Enum.filter(RDF.Dataset.quads(dataset), fn
        {_subject, _predicate, _object, %RDF.IRI{value: ^graph_iri}} -> true
        _other -> false
      end)

    transition_iris =
      quads
      |> Enum.flat_map(fn
        {%RDF.IRI{value: transition}, %RDF.IRI{value: @rdf_type},
         %RDF.IRI{value: @state_transition}, _graph} ->
          [transition]

        _other ->
          []
      end)

    if length(transition_iris) <= @max_transitions do
      transitions =
        transition_iris
        |> Enum.map(&decode_transition(&1, quads, subject_iri))

      if Enum.all?(transitions, &is_map/1), do: {:ok, transitions}, else: conflict()
    else
      conflict()
    end
  end

  defp decode_transition(transition, quads, expected_subject) do
    values = subject_values(quads, transition)

    with {:ok, subject} <- one_iri(values, @jf <> "transitionSubject"),
         true <- subject == expected_subject,
         {:ok, state_iri} <- one_iri(values, @jf <> "nextState"),
         {:ok, state} <- Map.fetch(@state_by_iri, state_iri),
         {:ok, revision} <- one_integer(values, @jf <> "subjectRevision"),
         {:ok, actor} <- one_iri(values, @prov_associated),
         {:ok, cause} <- one_iri(values, @jf <> "cause"),
         {:ok, reason} <- one_string(values, @jf <> "reason"),
         {:ok, generated_at} <- one_datetime(values, @prov_generated_at),
         {:ok, recorded_at} <- one_datetime(values, @jf <> "recordedAt"),
         {:ok, disposition} <- disposition(transition, quads) do
      %{
        transition_iri: transition,
        subject: subject,
        next_state: state,
        revision: revision,
        actor: actor,
        cause: cause,
        reason: reason,
        generated_at: generated_at,
        recorded_at: recorded_at,
        prior_state: optional_state(values, @jf <> "priorState"),
        expected_predecessor: optional_iri(values, @jf <> "expectedPredecessor"),
        fencing_token: optional_integer(values, @jf <> "fencingToken"),
        disposition: disposition
      }
    else
      _invalid -> nil
    end
  end

  defp disposition(transition, quads) do
    accepted = relationship_subjects(quads, @jf <> "accepts", transition)
    rejected = relationship_subjects(quads, @jf <> "rejects", transition)
    superseded = relationship_subjects(quads, @jf <> "supersedes", transition)

    case {accepted, rejected, superseded} do
      {[_decision], [], []} -> {:ok, :accepted}
      {[], [_decision], []} -> {:ok, :rejected}
      {[], [_decision], [_superseder]} -> {:ok, :superseded}
      {[], [], []} -> {:ok, :proposed}
      _ambiguous -> conflict()
    end
  end

  defp relationship_subjects(quads, predicate, object) do
    quads
    |> Enum.flat_map(fn
      {%RDF.IRI{value: subject}, %RDF.IRI{value: ^predicate}, %RDF.IRI{value: ^object}, _graph} ->
        [subject]

      _other ->
        []
    end)
    |> Enum.uniq()
  end

  defp subject_values(quads, subject) do
    Enum.reduce(quads, %{}, fn
      {%RDF.IRI{value: ^subject}, %RDF.IRI{value: predicate}, object, _graph}, values ->
        Map.update(values, predicate, [object], &[object | &1])

      _other, values ->
        values
    end)
  end

  defp one_iri(values, predicate) do
    case Map.get(values, predicate, []) do
      [%RDF.IRI{value: value}] -> {:ok, value}
      _invalid -> :error
    end
  end

  defp one_integer(values, predicate) do
    case Map.get(values, predicate, []) do
      [%RDF.Literal{} = literal] ->
        case RDF.Literal.value(literal) do
          value when is_integer(value) and value >= 0 -> {:ok, value}
          _invalid -> :error
        end

      _invalid ->
        :error
    end
  end

  defp one_string(values, predicate) do
    case Map.get(values, predicate, []) do
      [%RDF.Literal{} = literal] ->
        case RDF.Literal.value(literal) do
          value when is_binary(value) -> {:ok, value}
          _invalid -> :error
        end

      _invalid ->
        :error
    end
  end

  defp one_datetime(values, predicate) do
    case Map.get(values, predicate, []) do
      [%RDF.Literal{} = literal] ->
        case RDF.Literal.value(literal) do
          %DateTime{} = value -> {:ok, value}
          _invalid -> :error
        end

      _invalid ->
        :error
    end
  end

  defp optional_iri(values, predicate) do
    case Map.get(values, predicate, []) do
      [] -> nil
      [%RDF.IRI{value: value}] -> value
      _invalid -> :invalid
    end
  end

  defp optional_integer(values, predicate) do
    case Map.get(values, predicate, []) do
      [] ->
        nil

      _one ->
        case one_integer(values, predicate) do
          {:ok, value} -> value
          _error -> :invalid
        end
    end
  end

  defp optional_state(values, predicate) do
    case optional_iri(values, predicate) do
      nil -> nil
      iri -> Map.get(@state_by_iri, iri, :invalid)
    end
  end

  defp conflict, do: {:error, Error.new(:conflict, :current_state_resolution)}
end
