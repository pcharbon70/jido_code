defmodule JidoCode.Knowledge.Memory.ProcedureRevision do
  @moduledoc "Closed, non-authoritative reusable procedure revision."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ProcedureTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :purpose,
    :task_class,
    :task_phases,
    :triggers,
    :applicability,
    :repository_iri,
    :language,
    :framework,
    :framework_version,
    :steps,
    :required_tools,
    :required_capabilities,
    :expected_observations,
    :decision_branches,
    :stop_conditions,
    :escalation_conditions,
    :rollback_conditions,
    :exceptions,
    :supporting_case_iris,
    :contradicting_case_iris,
    :delayed_outcomes,
    :last_validated_at,
    :transition,
    :non_authoritative?
  ]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
  @revision "1.0.0"
  @phases ~w[investigation localization editing migration testing verification recovery incident]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"

  def revision, do: @revision
  def task_phases, do: @phases

  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes, [:repository_iri, :actor_iri, :cause_iri]),
         true <-
           text?(attributes[:purpose], 512) and
             attributes[:task_class] in ~w[diagnosis implementation repair review migration evaluation incident]a,
         true <- list_of?(attributes[:task_phases], &(&1 in @phases), 1, 8),
         true <- list_of?(attributes[:triggers], &text?(&1, 256), 1, 30),
         true <- applicability?(attributes[:applicability]),
         true <-
           Enum.all?([:language, :framework, :framework_version], &text?(attributes[&1], 128)),
         true <- ordered_steps?(attributes[:steps]),
         true <- list_of?(attributes[:required_tools], &text?(&1, 128), 0, 30),
         true <- iri_list?(attributes[:required_capabilities], 0, 30),
         true <- list_of?(attributes[:expected_observations], &text?(&1, 512), 1, 30),
         true <- branches?(attributes[:decision_branches]),
         true <-
           lists(attributes, [
             :stop_conditions,
             :escalation_conditions,
             :rollback_conditions,
             :exceptions
           ]),
         true <-
           iri_list?(attributes[:supporting_case_iris], 0, 50) and
             iri_list?(attributes[:contradicting_case_iris], 0, 50),
         true <- list_of?(attributes[:delayed_outcomes], &text?(&1, 512), 0, 30),
         true <-
           is_nil(attributes[:last_validated_at]) or
             is_struct(attributes[:last_validated_at], DateTime),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         {:ok, iri} <-
           ResourceIdentity.deterministic(:procedure_revision, identity_material(attributes)),
         {:ok, transition} <-
           ProcedureTransition.new(%{
             procedure_iri: iri,
             prior_state: nil,
             next_state: :candidate,
             revision: 0,
             expected_predecessor: nil,
             actor_iri: attributes.actor_iri,
             cause_iri: attributes.cause_iri,
             reason: "propose quarantined procedure revision",
             recorded_at: recorded_at
           }) do
      values =
        attributes
        |> Map.take(@enforce_keys)
        |> Map.merge(%{
          iri: iri,
          revision: @revision,
          transition: transition,
          non_authoritative?: true
        })

      {:ok, struct!(__MODULE__, values)}
    else
      _invalid -> {:error, Error.new(:invalid_input, :procedure_revision)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :procedure_revision)}
  end

  def new(_), do: {:error, Error.new(:invalid_input, :procedure_revision)}

  def statements(procedure) do
    [
      {procedure.iri, @rdf_type, RDF.iri(@jf <> "ProcedureRevision")},
      {procedure.iri, @jf <> "about", RDF.iri(procedure.repository_iri)},
      {procedure.iri, @jf <> "purpose", RDF.XSD.String.new(procedure.purpose)},
      {procedure.iri, @jf <> "taskClass", RDF.XSD.String.new(to_string(procedure.task_class))},
      {procedure.iri, @jf <> "language", RDF.XSD.String.new(procedure.language)},
      {procedure.iri, @jf <> "framework", RDF.XSD.String.new(procedure.framework)},
      {procedure.iri, @jf <> "frameworkVersion", RDF.XSD.String.new(procedure.framework_version)},
      {procedure.iri, @jf <> "nonAuthoritative", RDF.XSD.Boolean.new(true)}
    ] ++
      literals(procedure, :task_phases, "taskPhase") ++
      literals(procedure, :triggers, "trigger") ++
      literals(procedure, :steps, "procedureStep", & &1.instruction) ++
      literals(procedure, :required_tools, "requiredTool") ++
      iris(procedure, :required_capabilities, "requiresCapability") ++
      literals(procedure, :expected_observations, "expectedObservation") ++
      literals(procedure, :stop_conditions, "stopCondition") ++
      literals(procedure, :escalation_conditions, "escalationCondition") ++
      literals(procedure, :rollback_conditions, "rollbackCondition") ++
      literals(procedure, :exceptions, "exception") ++
      iris(procedure, :supporting_case_iris, "supports") ++
      iris(procedure, :contradicting_case_iris, "contradicts") ++
      ProcedureTransition.statements(procedure.transition)
  end

  defp identity_material(attributes),
    do:
      :erlang.term_to_binary(Map.drop(attributes, [:actor_iri, :cause_iri, :recorded_at]), [
        :deterministic
      ])

  defp resources(attributes, fields),
    do:
      if(Enum.all?(fields, &(ResourceIdentity.validate(attributes[&1]) == :ok)),
        do: :ok,
        else: :error
      )

  defp text?(value, max), do: is_binary(value) and byte_size(value) in 1..max

  defp list_of?(values, predicate, min, max),
    do: is_list(values) and length(values) in min..max and Enum.all?(values, predicate)

  defp iri_list?(values, min, max),
    do: list_of?(values, &(ResourceIdentity.validate(&1) == :ok), min, max)

  defp applicability?(value),
    do:
      is_map(value) and
        Enum.all?([:environment, :policy_version, :tool_versions], &Map.has_key?(value, &1))

  defp ordered_steps?(steps),
    do:
      list_of?(
        steps,
        &(is_map(&1) and is_integer(&1[:index]) and text?(&1[:instruction], 1_024)),
        1,
        50
      ) and Enum.map(steps, & &1.index) == Enum.to_list(1..length(steps))

  defp branches?(values),
    do:
      list_of?(
        values,
        &(is_map(&1) and text?(&1[:condition], 512) and text?(&1[:action], 512)),
        0,
        30
      )

  defp lists(attributes, fields),
    do: Enum.all?(fields, &list_of?(attributes[&1], fn value -> text?(value, 512) end, 0, 30))

  defp literals(item, field, predicate, mapper \\ &to_string/1),
    do:
      Enum.map(
        Map.fetch!(item, field),
        &{item.iri, @jf <> predicate, RDF.XSD.String.new(mapper.(&1))}
      )

  defp iris(item, field, predicate),
    do: Enum.map(Map.fetch!(item, field), &{item.iri, @jf <> predicate, RDF.iri(&1)})
end
