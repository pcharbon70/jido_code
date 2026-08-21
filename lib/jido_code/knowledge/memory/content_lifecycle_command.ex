defmodule JidoCode.Knowledge.Memory.ContentLifecycleCommand do
  @moduledoc "Lifecycle-writer commands for content state, holds, and classified erasure."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ContentErasurePlan
  alias JidoCode.Knowledge.Memory.ContentHold
  alias JidoCode.Knowledge.Memory.ContentLifecycleGraph
  alias JidoCode.Knowledge.Memory.ContentLifecycleTransition
  alias JidoCode.Knowledge.ResourceIdentity

  def transition(transition, repository, revision, attributes, options \\ [])

  def transition(
        %ContentLifecycleTransition{} = transition,
        repository,
        revision,
        attributes,
        options
      ) do
    guards =
      if transition.revision == 0 do
        [{:subject_absent, graph!(repository), transition.iri}]
      else
        [
          {:subject_present, graph!(repository), transition.expected_predecessor},
          {:subject_absent, graph!(repository), transition.iri}
        ]
      end

    build(
      "TransitionContentLifecycle",
      repository,
      revision,
      transition.iri,
      ContentLifecycleTransition.statements(transition),
      guards,
      attributes,
      options
    )
  end

  def transition(_transition, _repository, _revision, _attributes, _options), do: invalid()

  def hold(%ContentHold{} = hold, repository, revision, attributes, options \\ []) do
    {type, guards} =
      case {hold.revision, hold.state} do
        {0, :held} ->
          {"PlaceContentHold", [{:subject_absent, graph!(repository), hold.iri}]}

        {_revision, :release_pending} ->
          {"ReviewContentHold",
           [
             {:subject_present, graph!(repository), hold.expected_predecessor},
             {:subject_absent, graph!(repository), hold.iri}
           ]}

        {_revision, :held} ->
          {"ReviewContentHold",
           [
             {:subject_present, graph!(repository), hold.expected_predecessor},
             {:subject_absent, graph!(repository), hold.iri}
           ]}

        {_revision, :released} ->
          {"ReleaseContentHold",
           [
             {:subject_present, graph!(repository), hold.expected_predecessor},
             {:subject_absent, graph!(repository), hold.iri}
           ]}
      end

    build(
      type,
      repository,
      revision,
      hold.iri,
      ContentHold.statements(hold),
      guards,
      attributes,
      options
    )
  rescue
    _error -> invalid()
  end

  def erasure(plan, repository, revision, attributes, options \\ [])

  def erasure(plan, repository, revision, attributes, options) when is_map(plan) do
    with true <- plan[:retrieval_blocked?] == true do
      build(
        "RecordContentErasure",
        repository,
        revision,
        plan.iri,
        ContentErasurePlan.statements(plan),
        [
          {:subject_present, graph!(repository), plan.request_iri},
          {:subject_absent, graph!(repository), plan.iri}
        ],
        attributes,
        options
      )
    else
      _invalid -> invalid()
    end
  end

  def erasure(_plan, _repository, _revision, _attributes, _options), do: invalid()

  defp build(type, repository, revision, identity, statements, guards, attributes, options) do
    with {:ok, lifecycle_graph} <- graph(repository),
         true <- attributes[:expected_graph_revisions] == %{lifecycle_graph => revision},
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, Enum.join([type, identity], "\n")),
         {:ok, target} <-
           ContentLifecycleGraph.target(
             lifecycle_graph,
             revision,
             attributes[:repository_scope_iri],
             command_iri,
             attributes[:recorded_at],
             statements
           ) do
      CommandEnvelope.new(
        %{
          command_type: type,
          command_version: CommandRegistry.content_version(),
          command_iri: command_iri,
          principal_iri: attributes[:principal_iri],
          actor_iri: attributes[:actor_iri],
          delegated_agent_iri: attributes[:delegated_agent_iri],
          delegation_iri: attributes[:delegation_iri],
          scope_iri: attributes[:repository_scope_iri],
          idempotency_key: command_iri,
          correlation_iri: attributes[:correlation_iri],
          causation_iri: attributes[:causation_iri],
          ontology_version: "1.2.0",
          shape_version: "1.2.0",
          expected_dataset_revision: attributes[:expected_dataset_revision],
          expected_graph_revisions: attributes[:expected_graph_revisions],
          reason: attributes[:reason],
          payload: %{
            changes: [target],
            guards: guards,
            content_lifecycle_iri: identity,
            direct_side_effects: [],
            prompt_context: nil
          }
        },
        options
      )
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  end

  defp graph(repository),
    do: GraphRegistry.graph_iri(:content_lifecycle, %{repository: repository})

  defp graph!(repository), do: elem(graph(repository), 1)
  defp invalid, do: {:error, Error.new(:invalid_input, :content_lifecycle_command)}
end
