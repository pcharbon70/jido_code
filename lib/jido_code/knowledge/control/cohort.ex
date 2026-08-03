defmodule JidoCode.Knowledge.Control.Cohort do
  @moduledoc """
  Graph-defined repository cohorts and rebuildable membership publication.

  Cohort definitions are asserted policy. Query-derived memberships are
  disposable derived facts bound to exact source revisions and an evaluator
  version.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.DerivedGraphManager
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :name,
    :scope_iri,
    :owner_iri,
    :mode,
    :static_members,
    :evaluator,
    :closed_inputs
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @modes [:static, :query]
  @evaluators %{
    {:repository_attributes, "1.0.0"} => :factory_repository_cohort,
    {:organization_membership, "1.0.0"} => :factory_repository_cohort,
    {:language_semantics, "1.0.0"} => :source_modules,
    {:dependency_semantics, "1.0.0"} => :source_dependencies,
    {:capability_relationship, "1.0.0"} => :capability_strict_view
  }
  @max_members 100
  @max_inputs 8
  @max_paths 20

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with {:ok, name} <- name(attributes[:name]),
         :ok <- validate_resource(attributes[:scope_iri]),
         :ok <- validate_resource(attributes[:owner_iri]),
         mode when mode in @modes <- attributes[:mode],
         {:ok, members} <- members(mode, Map.get(attributes, :static_members, [])),
         {:ok, evaluator} <- evaluator(mode, Map.get(attributes, :evaluator)),
         {:ok, inputs} <- inputs(mode, Map.get(attributes, :closed_inputs, [])),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :repository_cohort,
             Enum.join([attributes[:scope_iri], name], "\n")
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         name: name,
         scope_iri: attributes[:scope_iri],
         owner_iri: attributes[:owner_iri],
         mode: mode,
         static_members: members,
         evaluator: evaluator,
         closed_inputs: inputs
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_cohort)
    end
  rescue
    _error -> invalid(:repository_cohort)
  end

  def new(_attributes), do: invalid(:repository_cohort)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = cohort) do
    [
      {cohort.iri, @rdf_type, RDF.iri(@jf <> "RepositoryCohort")},
      {cohort.iri, @jf <> "displayId", RDF.XSD.String.new(cohort.name)},
      {cohort.iri, @jf <> "validFor", RDF.iri(cohort.scope_iri)},
      {cohort.iri, @jf <> "ownedBy", RDF.iri(cohort.owner_iri)},
      {cohort.iri, @prov <> "wasAttributedTo", RDF.iri(cohort.owner_iri)},
      {cohort.iri, @jf <> "policyKind",
       RDF.iri(@concept <> "Cohort" <> Macro.camelize(to_string(cohort.mode)))}
    ] ++
      Enum.map(cohort.static_members, &{cohort.iri, @jf <> "staticMember", RDF.iri(&1)}) ++
      evaluator_statements(cohort) ++
      Enum.map(cohort.closed_inputs, &{cohort.iri, @jf <> "closedInput", RDF.iri(&1)})
  end

  @spec define_command(t(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), cohort: t()}} | {:error, Error.t()}
  def define_command(cohort, attributes, options \\ [])

  def define_command(%__MODULE__{} = cohort, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         target = %{
           family: :factory_policy,
           graph_iri: graph,
           operation: :append,
           metadata: %{lifecycle_state: :open},
           additions: statements(cohort),
           supersessions: [],
           invalidations: [],
           removals: []
         },
         {:ok, command} <-
           CommandEnvelope.new(
             %{
               command_type: "DefineRepositoryCohort",
               command_version: "1.3.0",
               command_iri: attributes[:command_iri],
               principal_iri: attributes[:principal_iri],
               actor_iri: attributes[:actor_iri],
               delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
               delegation_iri: Map.get(attributes, :delegation_iri),
               scope_iri: cohort.scope_iri,
               idempotency_key: attributes[:idempotency_key],
               correlation_iri: attributes[:correlation_iri],
               causation_iri: attributes[:causation_iri],
               ontology_version: "1.0.0",
               shape_version: "1.0.0",
               expected_dataset_revision: attributes[:expected_dataset_revision],
               expected_graph_revisions: %{graph => attributes[:expected_policy_revision]},
               reason: attributes[:reason],
               payload: %{
                 changes: [target],
                 guards: [{:subject_absent, graph, cohort.iri}]
               }
             },
             options
           ) do
      {:ok, %{command: command, cohort: cohort}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:define_repository_cohort_command)
    end
  end

  def define_command(_cohort, _attributes, _options),
    do: invalid(:define_repository_cohort_command)

  @spec publish_membership(t(), [map()], map(), keyword()) :: term()
  def publish_membership(cohort, memberships, attributes, options \\ [])

  def publish_membership(%__MODULE__{} = cohort, memberships, attributes, options)
      when is_list(memberships) and is_map(attributes) and is_list(options) do
    with true <- cohort.mode == :query,
         true <- length(memberships) <= @max_members,
         {:ok, statements} <- membership_statements(cohort, memberships, attributes),
         {:ok, target_graph} <-
           GraphRegistry.graph_iri(:derived, %{
             rule_set: attributes[:rule_set_slug],
             revision: attributes[:rule_revision]
           }),
         true <- target_graph == attributes[:target_graph_iri] do
      DerivedGraphManager.publish(
        %{
          operation: :publish,
          command_iri: attributes[:command_iri],
          authority: attributes[:authority],
          scope_iri: cohort.scope_iri,
          idempotency_key: attributes[:idempotency_key],
          correlation_iri: attributes[:correlation_iri],
          causation_iri: attributes[:causation_iri],
          ontology_version: "1.0.0",
          shape_version: "1.0.0",
          target_graph_iri: target_graph,
          rule_set_iri: attributes[:rule_set_iri],
          rule_set_slug: attributes[:rule_set_slug],
          rule_revision: attributes[:rule_revision],
          query_version: cohort.evaluator.version,
          source_graph_revisions: attributes[:source_graph_revisions],
          expected_prior_derivation: Map.get(attributes, :expected_prior_derivation),
          reason: attributes[:reason],
          statements: statements
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:publish_cohort_membership)
    end
  rescue
    _error -> invalid(:publish_cohort_membership)
  end

  def publish_membership(_cohort, _memberships, _attributes, _options),
    do: invalid(:publish_cohort_membership)

  @spec mark_membership_stale(t(), map(), keyword()) :: term()
  def mark_membership_stale(%__MODULE__{} = cohort, attributes, options \\ []) do
    DerivedGraphManager.publish(
      %{
        operation: :mark_stale,
        command_iri: attributes[:command_iri],
        authority: attributes[:authority],
        scope_iri: cohort.scope_iri,
        idempotency_key: attributes[:idempotency_key],
        correlation_iri: attributes[:correlation_iri],
        causation_iri: attributes[:causation_iri],
        ontology_version: "1.0.0",
        shape_version: "1.0.0",
        target_graph_iri: attributes[:target_graph_iri],
        rule_set_iri: attributes[:rule_set_iri],
        rule_set_slug: attributes[:rule_set_slug],
        rule_revision: attributes[:rule_revision],
        query_version: cohort.evaluator.version,
        source_graph_revisions: attributes[:source_graph_revisions],
        expected_prior_derivation: attributes[:expected_prior_derivation],
        reason: attributes[:reason],
        statements: []
      },
      options
    )
  end

  @spec explanation(t(), map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def explanation(%__MODULE__{} = cohort, membership, receipt)
      when is_map(membership) and is_map(receipt) do
    with :ok <- validate_resource(membership[:repository_iri]),
         {:ok, paths} <- resource_list(membership[:path], @max_paths),
         true <- is_map(receipt[:source_graph_revisions]) do
      {:ok,
       %{
         cohort_iri: cohort.iri,
         repository_iri: membership[:repository_iri],
         membership_path: paths,
         evaluator_iri: cohort.evaluator.iri,
         evaluator_version: cohort.evaluator.version,
         source_graph_revisions: receipt[:source_graph_revisions],
         complete?: Map.get(membership, :complete?, false),
         incomplete_reasons: Enum.take(Map.get(membership, :incomplete_reasons, []), 20)
       }}
    else
      _invalid -> invalid(:cohort_applicability_explanation)
    end
  end

  def explanation(_cohort, _membership, _receipt),
    do: invalid(:cohort_applicability_explanation)

  @spec membership_identity(t(), map(), map()) :: {:ok, String.t()} | {:error, Error.t()}
  def membership_identity(%__MODULE__{} = cohort, membership, attributes)
      when is_map(membership) and is_map(attributes) do
    source_digest =
      attributes[:source_graph_revisions]
      |> Enum.sort()
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ResourceIdentity.deterministic(
      :cohort_membership,
      Enum.join([cohort.iri, membership.repository_iri, source_digest], "\n")
    )
  rescue
    _error -> invalid(:cohort_membership_identity)
  end

  def membership_identity(_cohort, _membership, _attributes),
    do: invalid(:cohort_membership_identity)

  defp membership_statements(cohort, memberships, attributes) do
    Enum.reduce_while(memberships, {:ok, []}, fn membership, {:ok, statements} ->
      with :ok <- validate_resource(membership[:repository_iri]),
           {:ok, path} <- resource_list(membership[:path], @max_paths),
           true <- is_boolean(membership[:complete?]),
           {:ok, iri} <- membership_identity(cohort, membership, attributes) do
        values =
          [
            {iri, @rdf_type, RDF.iri(@jf <> "CohortMembership")},
            {iri, @jf <> "member", RDF.iri(membership[:repository_iri])},
            {iri, @jf <> "inCohort", RDF.iri(cohort.iri)},
            {iri, @jf <> "applicabilityEvaluator", RDF.iri(cohort.evaluator.iri)},
            {iri, @jf <> "completenessState",
             RDF.iri(@concept <> if(membership[:complete?], do: "Complete", else: "Incomplete"))}
          ] ++ Enum.map(path, &{iri, @jf <> "membershipPath", RDF.iri(&1)})

        {:cont, {:ok, values ++ statements}}
      else
        _invalid -> {:halt, invalid(:cohort_membership)}
      end
    end)
    |> case do
      {:ok, statements} -> {:ok, Enum.reverse(statements)}
      error -> error
    end
  end

  defp evaluator(:static, nil), do: {:ok, nil}

  defp evaluator(:query, %{name: name, version: version, query: query}) do
    with true <- Map.get(@evaluators, {name, version}) == query,
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :policy_evaluator,
             Enum.join([Atom.to_string(name), version, Atom.to_string(query)], "\n")
           ) do
      {:ok, %{iri: iri, name: name, version: version, query: query}}
    else
      _invalid -> invalid(:cohort_evaluator)
    end
  end

  defp evaluator(_mode, _evaluator), do: invalid(:cohort_evaluator)

  defp evaluator_statements(%__MODULE__{mode: :static}), do: []

  defp evaluator_statements(cohort) do
    [
      {cohort.iri, @jf <> "applicabilityEvaluator", RDF.iri(cohort.evaluator.iri)},
      {cohort.evaluator.iri, @rdf_type, RDF.iri(@prov <> "SoftwareAgent")},
      {cohort.evaluator.iri, @jf <> "version", RDF.XSD.String.new(cohort.evaluator.version)},
      {cohort.evaluator.iri, @jf <> "queryVersion",
       RDF.XSD.String.new(Atom.to_string(cohort.evaluator.query))}
    ]
  end

  defp members(:static, values), do: resource_list(values, @max_members, true)
  defp members(:query, []), do: {:ok, []}
  defp members(_mode, _values), do: invalid(:cohort_members)

  defp inputs(:static, []), do: {:ok, []}

  defp inputs(:query, values) when is_list(values) and length(values) in 1..@max_inputs do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &match?({:ok, _family}, GraphRegistry.identify(&1))),
      do: {:ok, values},
      else: invalid(:cohort_closed_inputs)
  end

  defp inputs(_mode, _values), do: invalid(:cohort_closed_inputs)

  defp resource_list(values, maximum, required? \\ false)

  defp resource_list(values, maximum, required?)
       when is_list(values) and length(values) <= maximum and (not required? or values != []) do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values},
      else: invalid(:cohort_references)
  end

  defp resource_list(_values, _maximum, _required), do: invalid(:cohort_references)

  defp name(value) when is_binary(value) and byte_size(value) in 1..128 do
    if Regex.match?(~r/^[a-z][a-z0-9._-]*$/, value), do: {:ok, value}, else: invalid(:cohort_name)
  end

  defp name(_value), do: invalid(:cohort_name)
  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
