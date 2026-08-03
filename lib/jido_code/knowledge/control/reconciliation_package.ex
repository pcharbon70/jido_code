defmodule JidoCode.Knowledge.Control.ReconciliationPackage do
  @moduledoc """
  Exact, bounded input context for one desired/observed reconciliation.

  This struct is transient. `statements/1` persists its semantic context and
  exact graph revisions with the reconciliation activity in the control graph.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :scope_iri,
    :repository_iri,
    :enrollment,
    :observation,
    :graph_references,
    :required_subjects,
    :desired_outcome_iris,
    :policy_iris,
    :knowledge_iris,
    :goal_iris,
    :obligation_iris,
    :knowledge_state,
    :query_version,
    :rule_version,
    :ontology_version,
    :actor_iri,
    :budget,
    :deadline,
    :requested_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @max_graphs 12
  @max_refs 100
  @knowledge_states ~w[known unknown contradictory]a
  @budget_bounds %{max_changes: 100, max_rows: 1_000, timeout_ms: 60_000}

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- validate_resource(attributes[:scope_iri]),
         :ok <- validate_resource(attributes[:repository_iri]),
         {:ok, enrollment} <- enrollment(attributes[:enrollment]),
         {:ok, observation} <-
           observation(attributes[:observation], attributes[:absence_checks?]),
         {:ok, references} <- graph_references(attributes),
         {:ok, required_subjects} <-
           required_subjects(attributes[:required_subjects], references),
         {:ok, desired} <- resources(attributes[:desired_outcome_iris], true),
         {:ok, policies} <- resources(attributes[:policy_iris], true),
         {:ok, knowledge} <- resources(attributes[:knowledge_iris], false),
         {:ok, goals} <- resources(attributes[:goal_iris], false),
         {:ok, obligations} <- resources(attributes[:obligation_iris], false),
         knowledge_state when knowledge_state in @knowledge_states <-
           attributes[:knowledge_state],
         true <- attributes[:query_version] == "1.4.0",
         {:ok, rule_version} <- semantic_version(attributes[:rule_version]),
         true <- attributes[:ontology_versions] == ["1.0.0"],
         :ok <- validate_resource(attributes[:actor_iri]),
         {:ok, budget} <- budget(attributes[:budget]),
         {:ok, requested_at, deadline} <-
           interval(attributes[:requested_at], attributes[:deadline]),
         {:ok, iri} <- identity(attributes, references, desired, policies) do
      {:ok,
       %__MODULE__{
         iri: iri,
         scope_iri: attributes[:scope_iri],
         repository_iri: attributes[:repository_iri],
         enrollment: enrollment,
         observation: observation,
         graph_references: references,
         required_subjects: required_subjects,
         desired_outcome_iris: desired,
         policy_iris: policies,
         knowledge_iris: knowledge,
         goal_iris: goals,
         obligation_iris: obligations,
         knowledge_state: knowledge_state,
         query_version: attributes[:query_version],
         rule_version: rule_version,
         ontology_version: "1.0.0",
         actor_iri: attributes[:actor_iri],
         budget: budget,
         deadline: deadline,
         requested_at: requested_at
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:reconciliation_package)
    end
  rescue
    _error -> invalid(:reconciliation_package)
  end

  def new(_attributes), do: invalid(:reconciliation_package)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = package) do
    [
      {package.iri, @rdf_type, RDF.iri(@jf <> "ReconciliationInput")},
      {package.iri, @jf <> "validFor", RDF.iri(package.scope_iri)},
      {package.iri, @jf <> "about", RDF.iri(package.repository_iri)},
      {package.iri, @jf <> "evaluatedContext", RDF.iri(package.enrollment.iri)},
      {package.iri, @jf <> "evidenceSource", RDF.iri(package.observation.batch_iri)},
      {package.iri, @jf <> "sourceSnapshot", RDF.iri(package.observation.snapshot_iri)},
      {package.iri, @jf <> "completenessState",
       RDF.iri(@concept <> if(package.observation.complete?, do: "Complete", else: "Incomplete"))},
      {package.iri, @jf <> "epistemicState",
       RDF.iri(@concept <> Macro.camelize(to_string(package.knowledge_state)))},
      {package.iri, @jf <> "queryVersion", RDF.XSD.String.new(package.query_version)},
      {package.iri, @jf <> "ruleVersion", RDF.XSD.String.new(package.rule_version)},
      {package.iri, @jf <> "ontologyVersion",
       RDF.iri("https://jido.run/ontology/release/#{package.ontology_version}")},
      {package.iri, @jf <> "rowLimit", RDF.XSD.NonNegativeInteger.new(package.budget.max_rows)},
      {package.iri, @jf <> "changeLimit",
       RDF.XSD.NonNegativeInteger.new(package.budget.max_changes)},
      {package.iri, @jf <> "timeoutMillis",
       RDF.XSD.NonNegativeInteger.new(package.budget.timeout_ms)},
      {package.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(package.requested_at)},
      {package.iri, @jf <> "validTo", RDF.XSD.DateTime.new(package.deadline)}
    ] ++
      Enum.map(
        package.desired_outcome_iris,
        &{package.iri, @jf <> "requiredOutcome", RDF.iri(&1)}
      ) ++
      Enum.map(package.policy_iris, &{package.iri, @jf <> "governedBy", RDF.iri(&1)}) ++
      Enum.map(package.knowledge_iris, &{package.iri, @jf <> "derivedFrom", RDF.iri(&1)}) ++
      Enum.map(package.goal_iris, &{package.iri, @jf <> "reuses", RDF.iri(&1)}) ++
      Enum.map(package.obligation_iris, &{package.iri, @jf <> "addresses", RDF.iri(&1)}) ++
      Enum.flat_map(package.graph_references, fn reference ->
        [
          {package.iri, @jf <> "sourceGraphRevision", RDF.iri(reference.iri)},
          {reference.iri, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
          {reference.iri, @jf <> "sourceGraph", RDF.iri(reference.graph_iri)},
          {reference.iri, @jf <> "sourceRevisionNumber",
           RDF.XSD.NonNegativeInteger.new(reference.revision)}
        ]
      end)
  end

  @spec graph_revisions(t()) :: %{String.t() => pos_integer()}
  def graph_revisions(%__MODULE__{} = package),
    do: Map.new(package.graph_references, &{&1.graph_iri, &1.revision})

  defp enrollment(%{
         iri: iri,
         state: :active,
         admission: :allowed,
         current_transition: transition
       }) do
    with :ok <- validate_resource(iri),
         :ok <- validate_resource(transition) do
      {:ok, %{iri: iri, state: :active, admission: :allowed, current_transition: transition}}
    end
  end

  defp enrollment(_value), do: invalid(:reconciliation_enrollment)

  defp observation(value, absence_checks?) when is_map(value) do
    with :ok <- validate_resource(value[:batch_iri]),
         :ok <- validate_resource(value[:snapshot_iri]),
         true <- is_boolean(value[:complete?]),
         true <- is_boolean(value[:contradictory?]),
         true <- absence_checks? != true or value[:complete?] do
      {:ok,
       %{
         batch_iri: value[:batch_iri],
         snapshot_iri: value[:snapshot_iri],
         complete?: value[:complete?],
         contradictory?: value[:contradictory?]
       }}
    else
      _invalid -> invalid(:reconciliation_observation)
    end
  end

  defp observation(_value, _absence_checks), do: invalid(:reconciliation_observation)

  defp graph_references(attributes) do
    expected = attributes[:graph_revisions]
    current = attributes[:current_graph_revisions]
    authorized = MapSet.new(attributes[:authorized_graphs] || [])

    with true <- is_map(expected) and map_size(expected) in 1..@max_graphs,
         true <- expected == current,
         true <- Enum.all?(Map.keys(expected), &MapSet.member?(authorized, &1)) do
      Enum.reduce_while(expected, {:ok, []}, fn {graph, revision}, {:ok, references} ->
        with {:ok, _family} <- GraphRegistry.identify(graph),
             true <- is_integer(revision) and revision > 0,
             {:ok, iri} <-
               ResourceIdentity.deterministic(
                 :graph_revision_reference,
                 graph <> "\n" <> Integer.to_string(revision)
               ) do
          {:cont, {:ok, [%{iri: iri, graph_iri: graph, revision: revision} | references]}}
        else
          _invalid -> {:halt, invalid(:reconciliation_graph_revisions)}
        end
      end)
      |> case do
        {:ok, references} -> {:ok, Enum.sort_by(references, & &1.graph_iri)}
        error -> error
      end
    else
      _invalid -> invalid(:reconciliation_graph_revisions)
    end
  end

  defp required_subjects(values, references) when is_map(values) do
    graphs = MapSet.new(references, & &1.graph_iri)

    valid? =
      map_size(values) <= @max_graphs and
        Enum.all?(values, fn {graph, resources} ->
          MapSet.member?(graphs, graph) and is_list(resources) and length(resources) <= @max_refs and
            Enum.all?(resources, &(ResourceIdentity.validate(&1) == :ok))
        end)

    if valid?,
      do: {:ok, Map.new(values, fn {graph, resources} -> {graph, Enum.uniq(resources)} end)},
      else: invalid(:reconciliation_required_subjects)
  end

  defp required_subjects(_values, _references),
    do: invalid(:reconciliation_required_subjects)

  defp resources(values, required?)
       when is_list(values) and length(values) <= @max_refs and (not required? or values != []) do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values},
      else: invalid(:reconciliation_references)
  end

  defp resources(_values, _required), do: invalid(:reconciliation_references)

  defp budget(values) when is_map(values) and map_size(values) == 3 do
    valid? =
      Enum.all?(@budget_bounds, fn {key, maximum} ->
        value = values[key]
        is_integer(value) and value in 1..maximum
      end)

    if valid?,
      do: {:ok, Map.take(values, Map.keys(@budget_bounds))},
      else: invalid(:reconciliation_budget)
  end

  defp budget(_values), do: invalid(:reconciliation_budget)

  defp interval(%DateTime{} = requested_at, %DateTime{} = deadline) do
    requested_at = DateTime.truncate(requested_at, :microsecond)
    deadline = DateTime.truncate(deadline, :microsecond)

    if DateTime.compare(requested_at, deadline) == :lt,
      do: {:ok, requested_at, deadline},
      else: invalid(:reconciliation_deadline)
  end

  defp interval(_requested_at, _deadline), do: invalid(:reconciliation_deadline)

  defp semantic_version(value) when is_binary(value) do
    if Regex.match?(~r/^\d+\.\d+\.\d+$/, value),
      do: {:ok, value},
      else: invalid(:reconciliation_rule_version)
  end

  defp semantic_version(_value), do: invalid(:reconciliation_rule_version)

  defp identity(attributes, references, desired, policies) do
    material =
      [attributes[:scope_iri], attributes[:query_version], attributes[:rule_version]] ++
        desired ++
        policies ++
        Enum.flat_map(references, &[&1.graph_iri, Integer.to_string(&1.revision)])

    ResourceIdentity.deterministic(:reconciliation_package, Enum.join(material, "\n"))
  end

  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
