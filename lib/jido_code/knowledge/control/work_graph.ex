defmodule JidoCode.Knowledge.Control.WorkGraph do
  @moduledoc """
  Builds goal, plan, task, and dependency graph commands.

  Work is persisted only as connected RDF resources and accepted transition
  chains. Maps returned by this module are bounded transient command receipts,
  not a durable `WorkItem` model.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Graph
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @max_refs 30
  @max_tasks 20
  @max_key_bytes 96
  @task_kinds ~w[change verification approval decision]a

  @spec propose_goal(map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), goal: map()}} | {:error, Error.t()}
  def propose_goal(attributes, options \\ [])

  def propose_goal(attributes, options) when is_map(attributes) and is_list(options) do
    enrollment = attributes[:enrollment]

    with :ok <- active_enrollment(enrollment),
         :ok <- validate_resource(attributes[:repository_iri]),
         :ok <- validate_resource(attributes[:repository_scope_iri]),
         :ok <- validate_resource(attributes[:actor_iri]),
         :ok <- validate_resource(attributes[:origin_activity_iri]),
         {:ok, addresses} <- resources(attributes[:addresses], true),
         {:ok, policies} <- resources(attributes[:policy_refs], false),
         {:ok, constraints} <- resources(attributes[:constraint_refs], false),
         {:ok, evidence} <- resources(attributes[:expected_evidence_refs], true),
         {:ok, key} <- semantic_key(attributes[:semantic_key]),
         {:ok, goal_iri} <- goal_identity(attributes, addresses, key),
         {:ok, transition} <- initial_transition(goal_iri, :goal, attributes),
         {:ok, control_graph} <- Graph.repository_control(attributes[:repository_iri]),
         true <- control_graph == attributes[:control_graph_iri],
         goal = %{
           iri: goal_iri,
           scope_iri: attributes[:repository_scope_iri],
           repository_iri: attributes[:repository_iri],
           addresses: addresses,
           policy_refs: policies,
           constraint_refs: constraints,
           expected_evidence_refs: evidence,
           origin_activity_iri: attributes[:origin_activity_iri],
           semantic_key: key,
           transition: transition
         },
         {:ok, target} <-
           Graph.target(
             control_graph,
             attributes[:expected_control_revision],
             attributes[:repository_scope_iri],
             attributes[:command_iri],
             attributes[:recorded_at],
             goal_statements(goal) ++ Transition.statements(transition)
           ),
         guards = [
           {:subject_absent, control_graph, goal_iri},
           enrollment_guard(enrollment)
         ],
         revisions = %{
           control_graph => attributes[:expected_control_revision],
           enrollment[:catalog_graph_iri] => enrollment[:catalog_revision]
         },
         {:ok, command} <-
           CommandEnvelope.new(
             envelope("ProposeGoal", attributes, revisions, [target], guards),
             options
           ) do
      {:ok, %{command: command, goal: goal}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:propose_goal_command)
    end
  rescue
    _error -> invalid(:propose_goal_command)
  end

  def propose_goal(_attributes, _options), do: invalid(:propose_goal_command)

  @spec propose_plan(map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), plan: map()}} | {:error, Error.t()}
  def propose_plan(attributes, options \\ [])

  def propose_plan(attributes, options) when is_map(attributes) and is_list(options) do
    enrollment = attributes[:enrollment]
    goal = attributes[:goal]

    with :ok <- active_enrollment(enrollment),
         :ok <- goal_context(goal),
         {:ok, :source_revision} <- GraphRegistry.identify(attributes[:source_graph_iri]),
         true <-
           is_integer(attributes[:source_graph_revision]) and
             attributes[:source_graph_revision] > 0,
         :ok <- validate_resource(attributes[:source_snapshot_iri]),
         :ok <- validate_resource(attributes[:planner_iri]),
         {:ok, planner_version} <- bounded_text(attributes[:planner_version], 128),
         {:ok, assumptions} <- resources(attributes[:assumption_refs], false),
         {:ok, effects} <- resources(attributes[:expected_effect_refs], true),
         {:ok, capabilities} <- resources(attributes[:available_capability_iris], false),
         {:ok, graph_references} <- input_graph_references(attributes),
         {:ok, specs} <- task_specs(attributes[:tasks], capabilities, attributes),
         :ok <- dependency_structure(specs),
         {:ok, plan_iri} <- plan_identity(attributes, goal, specs, planner_version),
         {:ok, tasks} <- task_resources(plan_iri, specs, attributes),
         {:ok, plan_transition} <- initial_transition(plan_iri, :plan, attributes),
         plan = %{
           iri: plan_iri,
           goal_iri: goal.iri,
           goal_transition_iri: goal.current_transition,
           repository_iri: attributes[:repository_iri],
           repository_scope_iri: attributes[:repository_scope_iri],
           source_graph_iri: attributes[:source_graph_iri],
           source_graph_revision: attributes[:source_graph_revision],
           source_snapshot_iri: attributes[:source_snapshot_iri],
           policy_graph_iri: attributes[:policy_graph_iri],
           policy_graph_revision: attributes[:policy_graph_revision],
           planner_iri: attributes[:planner_iri],
           planner_version: planner_version,
           assumptions: assumptions,
           expected_effects: effects,
           verification_strategy: attributes[:verification_strategy],
           graph_references: graph_references,
           tasks: tasks,
           transition: plan_transition
         },
         {:ok, target} <- plan_target(plan, attributes),
         {:ok, command} <- plan_command(plan, target, enrollment, attributes, options) do
      {:ok, %{command: command, plan: plan}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:propose_plan_command)
    end
  rescue
    _error -> invalid(:propose_plan_command)
  end

  def propose_plan(_attributes, _options), do: invalid(:propose_plan_command)

  @spec adopt_plan(map(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), plan: map(), transitions: [Transition.t()]}}
          | {:error, Error.t()}
  def adopt_plan(plan, attributes, options \\ [])

  def adopt_plan(plan, attributes, options)
      when is_map(plan) and is_map(attributes) and is_list(options) do
    with :ok <- adoptable_plan(plan, attributes),
         {:ok, plan_transition} <- next_transition(plan.transition, :plan, :approved, attributes),
         {:ok, task_transitions} <- approve_tasks(plan.tasks, attributes),
         transitions = [plan_transition | task_transitions],
         {:ok, adoption_iri} <-
           ResourceIdentity.deterministic(
             :plan_adoption,
             plan.iri <> "\n" <> attributes.actor_iri
           ),
         additions =
           Enum.flat_map(transitions, &Transition.statements/1) ++
             [
               {adoption_iri, @rdf_type, RDF.iri(@jf <> "Decision")},
               {adoption_iri, @jf <> "decisionAuthority", RDF.iri(attributes[:actor_iri])},
               {adoption_iri, @jf <> "accepts", RDF.iri(plan.iri)},
               {adoption_iri, @prov <> "generatedAtTime",
                RDF.XSD.DateTime.new(attributes[:recorded_at])}
             ],
         {:ok, target} <-
           Graph.target(
             attributes[:control_graph_iri],
             attributes[:expected_control_revision],
             attributes[:repository_scope_iri],
             attributes[:command_iri],
             attributes[:recorded_at],
             additions
           ),
         revisions = adoption_revisions(plan, attributes),
         guards =
           [
             {:transition_endpoint, attributes[:control_graph_iri], plan.iri,
              plan.transition.iri},
             {:transition_endpoint, attributes[:control_graph_iri], plan.goal_iri,
              plan.goal_transition_iri}
           ] ++
             Enum.map(plan.tasks, fn task ->
               {:transition_endpoint, attributes[:control_graph_iri], task.iri,
                task.transition.iri}
             end),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope("AdoptPlan", attributes, revisions, [target], guards),
             options
           ) do
      {:ok,
       %{
         command: command,
         plan: %{plan | transition: plan_transition},
         transitions: transitions,
         adoption_iri: adoption_iri
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:adopt_plan_command)
    end
  rescue
    _error -> invalid(:adopt_plan_command)
  end

  def adopt_plan(_plan, _attributes, _options), do: invalid(:adopt_plan_command)

  @spec transition_command(map(), map(), keyword()) ::
          {:ok, %{command: CommandEnvelope.t(), transition: Transition.t()}}
          | {:error, Error.t()}
  def transition_command(resolution, attributes, options \\ [])

  def transition_command(resolution, attributes, options)
      when is_map(resolution) and is_map(attributes) and is_list(options) do
    domain = resolution[:domain]

    with true <- domain in [:goal, :plan, :task],
         {:ok, transition} <-
           Transition.new(%{
             subject_iri: resolution[:subject_iri],
             domain: domain,
             prior_state: resolution[:current_state],
             next_state: attributes[:next_state],
             revision: resolution[:current_revision] + 1,
             expected_predecessor: resolution[:current_transition],
             actor_iri: attributes[:actor_iri],
             cause_iri: attributes[:causation_iri],
             reason: attributes[:reason],
             recorded_at: attributes[:recorded_at]
           }),
         {:ok, target} <-
           Graph.target(
             attributes[:control_graph_iri],
             attributes[:expected_control_revision],
             attributes[:repository_scope_iri],
             attributes[:command_iri],
             attributes[:recorded_at],
             Transition.statements(transition)
           ),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(
               "TransitionWork",
               attributes,
               %{attributes[:control_graph_iri] => attributes[:expected_control_revision]},
               [target],
               [Transition.guard(transition, attributes[:control_graph_iri])]
             ),
             options
           ) do
      {:ok, %{command: command, transition: transition}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_work_command)
    end
  end

  def transition_command(_resolution, _attributes, _options),
    do: invalid(:transition_work_command)

  defp goal_statements(goal) do
    [
      {goal.iri, @rdf_type, RDF.iri(@jf <> "Goal")},
      {goal.iri, @jf <> "about", RDF.iri(goal.repository_iri)},
      {goal.iri, @jf <> "validFor", RDF.iri(goal.scope_iri)},
      {goal.iri, @jf <> "originActivity", RDF.iri(goal.origin_activity_iri)},
      {goal.iri, @jf <> "displayId", RDF.XSD.String.new(goal.semantic_key)}
    ] ++
      Enum.map(goal.addresses, &{goal.iri, @jf <> "addresses", RDF.iri(&1)}) ++
      Enum.map(goal.policy_refs, &{goal.iri, @jf <> "governedBy", RDF.iri(&1)}) ++
      Enum.map(goal.constraint_refs, &{goal.iri, @jf <> "constrainedBy", RDF.iri(&1)}) ++
      Enum.map(goal.expected_evidence_refs, &{goal.iri, @jf <> "expectedEvidence", RDF.iri(&1)})
  end

  defp plan_target(plan, attributes) do
    additions =
      plan_statements(plan) ++
        Transition.statements(plan.transition) ++
        Enum.flat_map(plan.tasks, fn task ->
          task_statements(plan, task) ++ Transition.statements(task.transition)
        end)

    Graph.target(
      attributes[:control_graph_iri],
      attributes[:expected_control_revision],
      attributes[:repository_scope_iri],
      attributes[:command_iri],
      attributes[:recorded_at],
      additions
    )
  end

  defp plan_statements(plan) do
    [
      {plan.iri, @rdf_type, RDF.iri(@jf <> "Plan")},
      {plan.iri, @jf <> "about", RDF.iri(plan.goal_iri)},
      {plan.iri, @jf <> "validFor", RDF.iri(plan.repository_scope_iri)},
      {plan.iri, @jf <> "sourceGraph", RDF.iri(plan.source_graph_iri)},
      {plan.iri, @jf <> "sourceRevisionNumber",
       RDF.XSD.NonNegativeInteger.new(plan.source_graph_revision)},
      {plan.iri, @jf <> "sourceSnapshot", RDF.iri(plan.source_snapshot_iri)},
      {plan.iri, @jf <> "planner", RDF.iri(plan.planner_iri)},
      {plan.iri, @jf <> "displayId", RDF.XSD.String.new(plan.planner_version)},
      {plan.iri, @jf <> "verificationStrategy", RDF.XSD.String.new(plan.verification_strategy)}
    ] ++
      Enum.map(plan.assumptions, &{plan.iri, @jf <> "derivedFrom", RDF.iri(&1)}) ++
      Enum.map(plan.expected_effects, &{plan.iri, @jf <> "expectedEffect", RDF.iri(&1)}) ++
      Enum.map(plan.tasks, &{plan.iri, @jf <> "includesTask", RDF.iri(&1.iri)}) ++
      Enum.flat_map(plan.graph_references, fn reference ->
        [
          {plan.iri, @jf <> "sourceGraphRevision", RDF.iri(reference.iri)},
          {reference.iri, @rdf_type, RDF.iri(@jf <> "GraphRevisionReference")},
          {reference.iri, @jf <> "sourceGraph", RDF.iri(reference.graph_iri)},
          {reference.iri, @jf <> "sourceRevisionNumber",
           RDF.XSD.NonNegativeInteger.new(reference.revision)}
        ]
      end)
  end

  defp task_statements(plan, task) do
    [
      {task.iri, @rdf_type, RDF.iri(@jf <> "Task")},
      {task.iri, @jf <> "about", RDF.iri(plan.goal_iri)},
      {task.iri, @jf <> "validFor", RDF.iri(plan.repository_scope_iri)},
      {task.iri, @jf <> "taskKind",
       RDF.iri(@concept <> "Task" <> Macro.camelize(to_string(task.kind)))},
      {task.iri, @jf <> "displayId", RDF.XSD.String.new(task.key)}
    ] ++
      Enum.map(task.depends_on, &{task.iri, @jf <> "dependsOn", RDF.iri(&1)}) ++
      Enum.map(task.blocks, &{task.iri, @jf <> "blocks", RDF.iri(&1)}) ++
      Enum.map(task.alternative_to, &{task.iri, @jf <> "alternativeTo", RDF.iri(&1)}) ++
      Enum.map(task.required_artifacts, &{task.iri, @jf <> "requiresArtifact", RDF.iri(&1)}) ++
      Enum.map(task.required_capabilities, &{task.iri, @jf <> "requiresCapability", RDF.iri(&1)}) ++
      Enum.map(task.constraint_refs, &{task.iri, @jf <> "constrainedBy", RDF.iri(&1)}) ++
      if(task.iterative?,
        do: [{task.iri, @jf <> "iterationAllowed", RDF.XSD.Boolean.new(true)}],
        else: []
      )
  end

  defp plan_command(plan, target, enrollment, attributes, options) do
    control_graph = attributes[:control_graph_iri]

    revisions =
      plan.graph_references
      |> Map.new(&{&1.graph_iri, &1.revision})
      |> Map.put(control_graph, attributes[:expected_control_revision])
      |> Map.put(enrollment[:catalog_graph_iri], enrollment[:catalog_revision])

    guards =
      [
        {:subject_absent, control_graph, plan.iri},
        {:transition_endpoint, control_graph, plan.goal_iri, plan.goal_transition_iri},
        enrollment_guard(enrollment)
      ] ++ Enum.map(plan.tasks, &{:subject_absent, control_graph, &1.iri})

    CommandEnvelope.new(
      envelope("ProposePlan", attributes, revisions, [target], guards),
      options
    )
  end

  defp adoption_revisions(plan, attributes) do
    plan.graph_references
    |> Map.new(&{&1.graph_iri, &1.revision})
    |> Map.put(attributes[:control_graph_iri], attributes[:expected_control_revision])
  end

  defp adoptable_plan(plan, attributes) do
    cond do
      not is_list(plan[:tasks]) or plan.tasks == [] ->
        invalid(:adopt_plan_context)

      plan.transition.domain != :plan or plan.transition.next_state != :proposed ->
        invalid(:adopt_plan_state)

      plan.source_graph_iri != attributes[:source_graph_iri] or
          plan.source_graph_revision != attributes[:source_graph_revision] ->
        invalid(:adopt_plan_source_revision)

      plan.policy_graph_revision != attributes[:policy_graph_revision] ->
        invalid(:adopt_plan_policy_revision)

      Map.get(attributes, :assumptions_valid?, true) != true ->
        invalid(:adopt_plan_replanning_required)

      true ->
        :ok
    end
  end

  defp approve_tasks(tasks, attributes) do
    tasks
    |> Enum.reduce_while({:ok, []}, fn task, {:ok, transitions} ->
      case next_transition(task.transition, :task, :approved, attributes) do
        {:ok, transition} -> {:cont, {:ok, [transition | transitions]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, transitions} -> {:ok, Enum.reverse(transitions)}
      error -> error
    end
  end

  defp next_transition(prior, domain, next_state, attributes) do
    Transition.new(%{
      subject_iri: prior.subject_iri,
      domain: domain,
      prior_state: prior.next_state,
      next_state: next_state,
      revision: prior.revision + 1,
      expected_predecessor: prior.iri,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:causation_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp initial_transition(subject, domain, attributes) do
    Transition.new(%{
      subject_iri: subject,
      domain: domain,
      prior_state: nil,
      next_state: :proposed,
      revision: 0,
      expected_predecessor: nil,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:causation_iri],
      reason: attributes[:reason],
      recorded_at: attributes[:recorded_at]
    })
  end

  defp task_specs(values, available_capabilities, attributes)
       when is_list(values) and length(values) in 1..@max_tasks do
    with {:ok, specs} <- normalize_task_specs(values),
         :ok <- unique_task_keys(specs),
         :ok <- capability_coverage(specs, available_capabilities),
         :ok <- mandatory_tasks(specs, attributes) do
      {:ok, specs}
    end
  end

  defp task_specs(_values, _available, _attributes), do: invalid(:plan_tasks)

  defp normalize_task_specs(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, specs} ->
      case normalize_task_spec(value) do
        {:ok, spec} -> {:cont, {:ok, [spec | specs]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, specs} -> {:ok, Enum.reverse(specs)}
      error -> error
    end
  end

  defp normalize_task_spec(%{key: key, kind: kind} = spec) when kind in @task_kinds do
    with {:ok, key} <- task_key(key),
         {:ok, dependencies} <- task_keys(Map.get(spec, :depends_on, [])),
         {:ok, blocks} <- task_keys(Map.get(spec, :blocks, [])),
         {:ok, alternatives} <- task_keys(Map.get(spec, :alternative_to, [])),
         {:ok, artifacts} <- resources(Map.get(spec, :required_artifact_iris, []), false),
         {:ok, capabilities} <- resources(Map.get(spec, :required_capability_iris, []), false),
         {:ok, constraints} <- resources(Map.get(spec, :constraint_refs, []), false) do
      {:ok,
       %{
         key: key,
         kind: kind,
         depends_on: dependencies,
         blocks: blocks,
         alternative_to: alternatives,
         required_artifacts: artifacts,
         required_capabilities: capabilities,
         constraint_refs: constraints,
         iterative?: Map.get(spec, :iterative?, false) == true
       }}
    end
  end

  defp normalize_task_spec(_spec), do: invalid(:plan_task)

  defp task_resources(plan_iri, specs, attributes) do
    with {:ok, identities} <- task_identities(plan_iri, specs) do
      specs
      |> Enum.reduce_while({:ok, []}, fn spec, {:ok, tasks} ->
        iri = Map.fetch!(identities, spec.key)

        with {:ok, transition} <- initial_transition(iri, :task, attributes) do
          task = %{
            iri: iri,
            key: spec.key,
            kind: spec.kind,
            depends_on: Enum.map(spec.depends_on, &Map.fetch!(identities, &1)),
            blocks: Enum.map(spec.blocks, &Map.fetch!(identities, &1)),
            alternative_to: Enum.map(spec.alternative_to, &Map.fetch!(identities, &1)),
            required_artifacts: spec.required_artifacts,
            required_capabilities: spec.required_capabilities,
            constraint_refs: spec.constraint_refs,
            iterative?: spec.iterative?,
            transition: transition
          }

          {:cont, {:ok, [task | tasks]}}
        else
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end
      end)
      |> case do
        {:ok, tasks} -> {:ok, Enum.reverse(tasks)}
        error -> error
      end
    end
  end

  defp task_identities(plan_iri, specs) do
    specs
    |> Enum.reduce_while({:ok, %{}}, fn spec, {:ok, identities} ->
      case ResourceIdentity.deterministic(:task_proposal, plan_iri <> "\n" <> spec.key) do
        {:ok, iri} -> {:cont, {:ok, Map.put(identities, spec.key, iri)}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp input_graph_references(attributes) do
    values = attributes[:input_graph_revisions]

    if is_map(values) and map_size(values) in 2..10 and
         values[attributes[:source_graph_iri]] == attributes[:source_graph_revision] and
         values[attributes[:policy_graph_iri]] == attributes[:policy_graph_revision] do
      Enum.reduce_while(values, {:ok, []}, fn {graph, revision}, {:ok, references} ->
        with {:ok, _family} <- GraphRegistry.identify(graph),
             true <- is_integer(revision) and revision > 0,
             {:ok, iri} <-
               ResourceIdentity.deterministic(
                 :graph_revision_reference,
                 graph <> "\n" <> Integer.to_string(revision)
               ) do
          {:cont, {:ok, [%{iri: iri, graph_iri: graph, revision: revision} | references]}}
        else
          _invalid -> {:halt, invalid(:plan_input_graph_revisions)}
        end
      end)
      |> case do
        {:ok, references} -> {:ok, Enum.sort_by(references, & &1.graph_iri)}
        error -> error
      end
    else
      invalid(:plan_input_graph_revisions)
    end
  end

  defp dependency_structure(specs) do
    keys = MapSet.new(Enum.map(specs, & &1.key))

    valid_refs? =
      Enum.all?(specs, fn spec ->
        Enum.all?(spec.depends_on ++ spec.blocks ++ spec.alternative_to, fn key ->
          MapSet.member?(keys, key) and key != spec.key
        end)
      end)

    cond do
      not valid_refs? -> invalid(:plan_dependency_reference)
      acyclic?(specs) -> :ok
      Enum.all?(specs, & &1.iterative?) -> :ok
      true -> invalid(:plan_dependency_cycle)
    end
  end

  defp acyclic?(specs) do
    dependencies = Map.new(specs, &{&1.key, MapSet.new(&1.depends_on)})
    remove_roots(dependencies)
  end

  defp remove_roots(dependencies) when map_size(dependencies) == 0, do: true

  defp remove_roots(dependencies) do
    roots = for {key, values} <- dependencies, MapSet.size(values) == 0, do: key

    if roots == [] do
      false
    else
      remaining = Map.drop(dependencies, roots)
      root_set = MapSet.new(roots)

      remove_roots(
        Map.new(remaining, fn {key, values} -> {key, MapSet.difference(values, root_set)} end)
      )
    end
  end

  defp capability_coverage(specs, available) do
    required = specs |> Enum.flat_map(& &1.required_capabilities) |> MapSet.new()

    if MapSet.subset?(required, MapSet.new(available)),
      do: :ok,
      else: invalid(:plan_capability_coverage)
  end

  defp mandatory_tasks(specs, attributes) do
    verification? = Enum.any?(specs, &(&1.kind == :verification))
    approval? = Enum.any?(specs, &(&1.kind == :approval))

    if (not Map.get(attributes, :require_verification?, true) or verification?) and
         (not Map.get(attributes, :require_approval?, false) or approval?) do
      :ok
    else
      invalid(:plan_mandatory_tasks)
    end
  end

  defp plan_identity(attributes, goal, specs, planner_version) do
    material =
      {
        goal.iri,
        attributes[:source_graph_iri],
        attributes[:source_graph_revision],
        attributes[:source_snapshot_iri],
        attributes[:policy_graph_iri],
        attributes[:policy_graph_revision],
        attributes[:planner_iri],
        planner_version,
        specs,
        Enum.sort(attributes[:assumption_refs]),
        Enum.sort(attributes[:expected_effect_refs])
      }
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ResourceIdentity.deterministic(:plan_proposal, material)
  end

  defp goal_identity(attributes, addresses, key) do
    ResourceIdentity.deterministic(
      :goal_proposal,
      Enum.join([attributes.repository_scope_iri, key | addresses], "\n")
    )
  end

  defp goal_context(%{
         iri: iri,
         current_state: state,
         current_transition: transition
       })
       when state in [:proposed, :approved, :eligible, :blocked] do
    with :ok <- validate_resource(iri), :ok <- validate_resource(transition), do: :ok
  end

  defp goal_context(_goal), do: invalid(:plan_goal_context)

  defp active_enrollment(%{
         enrollment_iri: enrollment,
         current_transition: transition,
         current_state: :active,
         admission: :allowed,
         catalog_graph_iri: graph,
         catalog_revision: revision
       })
       when is_integer(revision) and revision > 0 do
    with :ok <- validate_resource(enrollment),
         :ok <- validate_resource(transition),
         {:ok, :factory_catalog} <- GraphRegistry.identify(graph),
         do: :ok
  end

  defp active_enrollment(_enrollment), do: invalid(:work_enrollment)

  defp enrollment_guard(enrollment) do
    {:transition_endpoint, enrollment.catalog_graph_iri, enrollment.enrollment_iri,
     enrollment.current_transition}
  end

  defp envelope(type, attributes, revisions, changes, guards) do
    %{
      command_type: type,
      command_version: "1.2.0",
      command_iri: attributes[:command_iri],
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:repository_scope_iri],
      idempotency_key: attributes[:idempotency_key],
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: revisions,
      reason: attributes[:reason],
      payload: %{changes: changes, guards: guards}
    }
  end

  defp resources(values, required?)
       when is_list(values) and length(values) <= @max_refs and (not required? or values != []) do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values},
      else: invalid(:work_references)
  end

  defp resources(_values, _required), do: invalid(:work_references)

  defp task_keys(values) when is_list(values) and length(values) <= @max_tasks do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, keys} ->
      case task_key(value) do
        {:ok, key} -> {:cont, {:ok, [key | keys]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, keys} -> {:ok, keys |> Enum.uniq() |> Enum.sort()}
      error -> error
    end
  end

  defp task_keys(_values), do: invalid(:plan_task_keys)

  defp unique_task_keys(specs) do
    keys = Enum.map(specs, & &1.key)
    if length(keys) == length(Enum.uniq(keys)), do: :ok, else: invalid(:plan_task_keys)
  end

  defp task_key(value) when is_binary(value) and byte_size(value) in 1..@max_key_bytes do
    if Regex.match?(~r/^[a-z][a-z0-9._-]*$/, value),
      do: {:ok, value},
      else: invalid(:plan_task_key)
  end

  defp task_key(_value), do: invalid(:plan_task_key)

  defp semantic_key(value) when is_binary(value) and byte_size(value) in 1..128 do
    if value == String.trim(value), do: {:ok, value}, else: invalid(:goal_semantic_key)
  end

  defp semantic_key(_value), do: invalid(:goal_semantic_key)

  defp bounded_text(value, maximum) when is_binary(value) and is_integer(maximum) do
    if byte_size(value) >= 1 and byte_size(value) <= maximum,
      do: {:ok, value},
      else: invalid(:work_text)
  end

  defp bounded_text(_value, _maximum), do: invalid(:work_text)

  defp validate_resource(value), do: ResourceIdentity.validate(value)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
