defmodule JidoCode.Product.ReadProjectionQuery do
  @moduledoc "Closed HUI-C4 admission boundary for reviewed graph reads."

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity

  @version "2.11.0"
  @bindings %{
    factory_cohort: {:factory_repository_cohort, [:graph, :resource]},
    repository_description: {:repository_description, [:graph, :resource]},
    active_enrollment: {:active_enrollment, [:graph, :resource]},
    provider_freshness: {:provider_freshness, [:graph, :resource]},
    work_lens: {:work_lens, [:graph, :state]},
    active_attempts: {:active_attempts, [:graph]},
    attempt_status: {:attempt_status, [:graph, :resource]},
    attempt_timeline: {:attempt_timeline, [:graph, :resource]},
    managed_attempt: {:managed_coding_attempt, [:graph, :resource]},
    managed_observations: {:managed_coding_observations, [:graph, :resource]},
    interaction_session: {:interaction_session, [:graph, :resource]},
    interaction_timeline: {:interaction_timeline, [:graph, :resource]},
    attempt_artifacts: {:attempt_artifacts, [:graph, :resource]},
    tool_invocations: {:tool_invocations, [:graph, :resource]},
    run_completeness: {:run_completeness, [:graph, :resource]},
    evidence_by_attempt: {:evidence_by_attempt, [:graph, :resource]},
    wiki_enrollment: {:repository_wiki_enrollment_detail, [:graph, :resource]},
    wiki_current_edition:
      {:repository_wiki_current_edition, [:control_graph, :resource, :wiki_graph]},
    wiki_costs: {:repository_wiki_cost_records, [:graph, :instant, :resource]},
    source_dependencies: {:source_dependencies, [:graph, :snapshot]}
  }
  @work_states [:eligible, :blocked, :executing, :awaiting_decision]

  @spec version() :: String.t()
  def version, do: @version

  @spec bindings() :: [atom()]
  def bindings, do: @bindings |> Map.keys() |> Enum.sort()

  @spec execute(function(), atom(), map(), AuthorityContext.t(), String.t()) :: term()
  def execute(query, binding, parameters, authority, scope_iri)
      when is_function(query, 6) and is_atom(binding) and is_map(parameters) do
    with {:ok, {name, expected_keys}} <- Map.fetch(@bindings, binding),
         true <- Map.keys(parameters) |> Enum.sort() == Enum.sort(expected_keys),
         :ok <- validate_parameters(binding, parameters),
         {:ok, definition} <- QueryCatalog.fetch(name, @version),
         true <- definition.execution_class in [:product, :diagnostic],
         %AuthorityContext{} <- authority,
         :ok <- ResourceIdentity.validate(scope_iri) do
      query.(name, @version, parameters, authority, scope_iri, [])
    else
      _invalid -> {:error, Error.new(:invalid_input, :hui_c4_read_query)}
    end
  end

  def execute(_query, _binding, _parameters, _authority, _scope_iri),
    do: {:error, Error.new(:invalid_input, :hui_c4_read_query)}

  defp validate_parameters(:factory_cohort, parameters),
    do: graph_resource(parameters, :factory_catalog)

  defp validate_parameters(binding, %{graph: graph, resource: resource})
       when binding in [
              :repository_description,
              :active_enrollment,
              :provider_freshness,
              :attempt_status,
              :attempt_timeline,
              :managed_attempt,
              :managed_observations,
              :interaction_session,
              :interaction_timeline,
              :attempt_artifacts,
              :tool_invocations,
              :run_completeness,
              :evidence_by_attempt,
              :wiki_enrollment
            ] do
    with :ok <- graph_family(graph, family(binding)), do: ResourceIdentity.validate(resource)
  end

  defp validate_parameters(:work_lens, %{graph: graph, state: state})
       when state in @work_states,
       do: graph_family(graph, :repository_control)

  defp validate_parameters(:active_attempts, %{graph: graph}),
    do: graph_family(graph, :repository_control)

  defp validate_parameters(:wiki_current_edition, %{
         control_graph: control_graph,
         resource: resource,
         wiki_graph: wiki_graph
       }) do
    with :ok <- graph_family(control_graph, :repository_control),
         :ok <- graph_family(wiki_graph, :repository_wiki),
         :ok <- ResourceIdentity.validate(resource) do
      :ok
    end
  end

  defp validate_parameters(:wiki_costs, %{graph: graph, instant: %DateTime{}, resource: resource}) do
    with :ok <- graph_family(graph, :run_attempt), do: ResourceIdentity.validate(resource)
  end

  defp validate_parameters(:source_dependencies, %{graph: graph, snapshot: snapshot}) do
    with :ok <- graph_family(graph, :source_revision), do: ResourceIdentity.validate(snapshot)
  end

  defp validate_parameters(_binding, _parameters),
    do: {:error, Error.new(:invalid_input, :hui_c4_read_query)}

  defp graph_resource(%{graph: graph, resource: resource}, family) do
    with :ok <- graph_family(graph, family), do: ResourceIdentity.validate(resource)
  end

  defp graph_family(graph, expected) do
    case GraphRegistry.identify(graph) do
      {:ok, ^expected} -> :ok
      _invalid -> {:error, Error.new(:invalid_input, :hui_c4_read_query_graph)}
    end
  end

  defp family(binding)
       when binding in [:repository_description, :active_enrollment],
       do: :factory_catalog

  defp family(:provider_freshness), do: :observation_batch

  defp family(binding)
       when binding in [:wiki_enrollment],
       do: :repository_control

  defp family(:evidence_by_attempt), do: :evidence

  defp family(binding)
       when binding in [
              :attempt_status,
              :attempt_timeline,
              :managed_attempt,
              :interaction_session,
              :interaction_timeline,
              :attempt_artifacts,
              :tool_invocations,
              :run_completeness
            ],
       do: :run_attempt

  defp family(:managed_observations), do: :run_event_segment
end
