defmodule JidoCode.Knowledge.Evidence.VerificationActivity do
  @moduledoc "Advisory verification over exact run, source, and artifact inputs."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.Artifact
  alias JidoCode.Knowledge.Evidence.VerificationMethod
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :method,
    :attempt_iri,
    :task_iri,
    :goal_iri,
    :run_graph_iri,
    :control_graph_iri,
    :source_graph_iri,
    :source_snapshot_iri,
    :proposed_snapshot_iri,
    :post_change_snapshot_iri,
    :artifacts,
    :source_graph_revisions,
    :evaluator_iri,
    :execution_actor_iri,
    :environment,
    :checks,
    :completeness,
    :started_at,
    :ended_at,
    :raw_outcome_refs
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @statuses ~w[passed failed skipped unknown]a
  @jf "https://jido.run/ontology/factory#"
  @prov "http://www.w3.org/ns/prov#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @concept "https://jido.run/ontology/concept/"

  @spec new(VerificationMethod.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(%VerificationMethod{} = method, attributes) when is_map(attributes) do
    with true <- VerificationMethod.supported?(method.kind, method.version),
         :ok <-
           resources([attributes[:attempt_iri], attributes[:task_iri], attributes[:goal_iri]]),
         {:ok, :run_attempt} <- GraphRegistry.identify(attributes[:run_graph_iri]),
         {:ok, :repository_control} <- GraphRegistry.identify(attributes[:control_graph_iri]),
         {:ok, :source_revision} <- GraphRegistry.identify(attributes[:source_graph_iri]),
         :ok <- ResourceIdentity.validate(attributes[:source_snapshot_iri]),
         :ok <- optional_resource(attributes[:proposed_snapshot_iri]),
         :ok <- optional_resource(attributes[:post_change_snapshot_iri]),
         :ok <- ResourceIdentity.validate(attributes[:evaluator_iri]),
         :ok <- ResourceIdentity.validate(attributes[:execution_actor_iri]),
         true <- independent?(method, attributes),
         true <- attributes[:environment] == method.environment,
         {:ok, revisions} <- revisions(attributes[:source_graph_revisions], attributes),
         {:ok, artifacts} <- artifacts(attributes[:artifacts], attributes, method),
         {:ok, checks} <- checks(attributes[:checks], method),
         completeness when completeness in [:complete, :incomplete] <- attributes[:completeness],
         true <- complete?(method, completeness, checks),
         {:ok, started_at, ended_at} <- interval(attributes[:started_at], attributes[:ended_at]),
         true <-
           DateTime.diff(ended_at, started_at, :millisecond) <= method.bounds.max_duration_ms,
         {:ok, raw_refs} <- bounded_resources(attributes[:raw_outcome_refs], 50),
         true <- snapshot_inputs_present?(method, attributes),
         {:ok, iri} <- identity(method, attributes, artifacts, checks, revisions) do
      {:ok,
       %__MODULE__{
         iri: iri,
         method: method,
         attempt_iri: attributes[:attempt_iri],
         task_iri: attributes[:task_iri],
         goal_iri: attributes[:goal_iri],
         run_graph_iri: attributes[:run_graph_iri],
         control_graph_iri: attributes[:control_graph_iri],
         source_graph_iri: attributes[:source_graph_iri],
         source_snapshot_iri: attributes[:source_snapshot_iri],
         proposed_snapshot_iri: attributes[:proposed_snapshot_iri],
         post_change_snapshot_iri: attributes[:post_change_snapshot_iri],
         artifacts: artifacts,
         source_graph_revisions: revisions,
         evaluator_iri: attributes[:evaluator_iri],
         execution_actor_iri: attributes[:execution_actor_iri],
         environment: attributes[:environment],
         checks: checks,
         completeness: completeness,
         started_at: started_at,
         ended_at: ended_at,
         raw_outcome_refs: raw_refs
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:verification_activity)
    end
  rescue
    _error -> invalid(:verification_activity)
  end

  def new(_method, _attributes), do: invalid(:verification_activity)

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = activity) do
    [
      {activity.iri, @rdf_type, RDF.iri(@jf <> "VerificationActivity")},
      {activity.iri, @rdf_type, RDF.iri(@prov <> "Activity")},
      {activity.iri, @jf <> "usesVerificationMethod", RDF.iri(activity.method.iri)},
      {activity.iri, @jf <> "evaluatedAttempt", RDF.iri(activity.attempt_iri)},
      {activity.iri, @jf <> "evaluatedTask", RDF.iri(activity.task_iri)},
      {activity.iri, @jf <> "evaluatedGoal", RDF.iri(activity.goal_iri)},
      {activity.iri, @jf <> "evaluatedSnapshot", RDF.iri(activity.source_snapshot_iri)},
      {activity.iri, @jf <> "evaluatorCapability",
       RDF.iri(activity.method.evaluator_capability_iri)},
      {activity.iri, @prov <> "wasAssociatedWith", RDF.iri(activity.evaluator_iri)},
      {activity.iri, @prov <> "startedAtTime", RDF.XSD.DateTime.new(activity.started_at)},
      {activity.iri, @prov <> "endedAtTime", RDF.XSD.DateTime.new(activity.ended_at)},
      {activity.iri, @jf <> "completenessState",
       RDF.iri(@concept <> Macro.camelize(to_string(activity.completeness)))},
      {activity.iri, @jf <> "environmentDigest", RDF.XSD.String.new(digest(activity.environment))}
    ] ++
      optional_iri(activity.iri, @jf <> "evaluatedSnapshot", activity.proposed_snapshot_iri) ++
      optional_iri(activity.iri, @jf <> "evaluatedSnapshot", activity.post_change_snapshot_iri) ++
      Enum.map(activity.artifacts, fn artifact ->
        {activity.iri, @jf <> "evaluatesArtifact", RDF.iri(artifact.iri)}
      end) ++
      Enum.map(activity.raw_outcome_refs, fn raw_ref ->
        {activity.iri, @jf <> "rawOutcome", RDF.iri(raw_ref)}
      end) ++
      check_statements(activity)
  end

  defp artifacts(values, attributes, method)
       when is_list(values) and values != [] and length(values) <= method.bounds.max_artifacts do
    options =
      case attributes[:artifact_fetch] do
        fetch when is_function(fetch, 1) -> [fetch: fetch]
        _none -> []
      end

    snapshots =
      [
        attributes[:source_snapshot_iri],
        attributes[:proposed_snapshot_iri],
        attributes[:post_change_snapshot_iri]
      ]
      |> Enum.reject(&is_nil/1)

    if Enum.all?(values, fn
         %Artifact{} = artifact ->
           artifact.base_snapshot_iri in snapshots and Artifact.verify(artifact, options) == :ok

         _invalid ->
           false
       end) do
      refs =
        values
        |> Enum.map(fn artifact ->
          %{
            iri: artifact.iri,
            digest: artifact.content_digest,
            source_snapshot_iri: artifact.base_snapshot_iri,
            media_type: artifact.media_type,
            byte_count: artifact.byte_count,
            verified?: true
          }
        end)
        |> Enum.sort_by(& &1.iri)

      {:ok, refs}
    else
      :error
    end
  end

  defp artifacts(_values, _attributes, _method), do: :error

  defp checks(values, method)
       when is_list(values) and values != [] and length(values) <= method.bounds.max_checks do
    decoded = Enum.map(values, &check/1)

    if Enum.all?(decoded, &match?({:ok, _}, &1)) do
      checks = decoded |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.id)

      if checks |> Enum.map(& &1.id) |> Enum.uniq() |> length() == length(checks),
        do: {:ok, checks},
        else: :error
    else
      :error
    end
  end

  defp checks(_values, _method), do: :error

  defp check(%{id: id, status: status, mandatory?: mandatory?} = check)
       when is_binary(id) and byte_size(id) in 1..160 and status in @statuses and
              is_boolean(mandatory?) do
    with false <- Regex.match?(~r/[\x00-\x1F\x7F]/u, id),
         {:ok, refs} <- bounded_resources(Map.get(check, :outcome_refs, []), 10) do
      {:ok, %{id: id, status: status, mandatory?: mandatory?, outcome_refs: refs}}
    else
      _invalid -> :error
    end
  end

  defp check(_check), do: :error

  defp revisions(value, attributes) when is_map(value) and map_size(value) in 3..8 do
    required = [
      attributes[:run_graph_iri],
      attributes[:control_graph_iri],
      attributes[:source_graph_iri]
    ]

    if Enum.sort(Map.keys(value)) == Enum.sort(required) and
         Enum.all?(value, fn {graph, revision} ->
           match?({:ok, _}, GraphRegistry.identify(graph)) and is_integer(revision) and
             revision > 0
         end),
       do: {:ok, value},
       else: :error
  end

  defp revisions(_value, _attributes), do: :error

  defp complete?(%VerificationMethod{requires_complete?: true}, :complete, checks),
    do: Enum.all?(checks, &(!&1.mandatory? or &1.status == :passed))

  defp complete?(%VerificationMethod{requires_complete?: true}, _state, _checks), do: false
  defp complete?(_method, _state, _checks), do: true

  defp independent?(%VerificationMethod{independent_evaluator?: true}, attributes),
    do: attributes[:evaluator_iri] != attributes[:execution_actor_iri]

  defp independent?(_method, _attributes), do: true

  defp snapshot_inputs_present?(method, attributes) do
    (:proposed_snapshot not in method.input_classes or
       not is_nil(attributes[:proposed_snapshot_iri])) and
      (:post_change_snapshot not in method.input_classes or
         not is_nil(attributes[:post_change_snapshot_iri]))
  end

  defp interval(%DateTime{} = started_at, %DateTime{} = ended_at) do
    if DateTime.compare(started_at, ended_at) in [:lt, :eq],
      do: {:ok, started_at, ended_at},
      else: :error
  end

  defp interval(_started_at, _ended_at), do: :error

  defp identity(method, attributes, artifacts, checks, revisions) do
    material =
      {
        method.iri,
        attributes[:attempt_iri],
        attributes[:task_iri],
        attributes[:goal_iri],
        attributes[:source_snapshot_iri],
        attributes[:proposed_snapshot_iri],
        attributes[:post_change_snapshot_iri],
        Enum.map(artifacts, &{&1.iri, &1.digest}),
        checks,
        revisions,
        attributes[:evaluator_iri],
        attributes[:started_at],
        attributes[:ended_at]
      }
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ResourceIdentity.deterministic(:verification_activity, material)
  end

  defp check_statements(activity) do
    Enum.flat_map(activity.checks, fn check ->
      {:ok, iri} =
        ResourceIdentity.deterministic(:verification_check, activity.iri <> "\n" <> check.id)

      [
        {activity.iri, @jf <> "hasCheck", RDF.iri(iri)},
        {iri, @rdf_type, RDF.iri(@jf <> "VerificationCheck")},
        {iri, @jf <> "displayId", RDF.XSD.String.new(check.id)},
        {iri, @jf <> "checkStatus", RDF.iri(@concept <> Macro.camelize(to_string(check.status)))},
        {iri, @jf <> "mandatory", RDF.XSD.Boolean.new(check.mandatory?)}
      ] ++
        Enum.map(check.outcome_refs, fn output ->
          {iri, @jf <> "rawOutcome", RDF.iri(output)}
        end)
    end)
  end

  defp bounded_resources(values, maximum) when is_list(values) and length(values) <= maximum do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp bounded_resources(_values, _maximum), do: :error

  defp resources(values),
    do: if(Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)), do: :ok, else: :error)

  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: ResourceIdentity.validate(value)
  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, object), do: [{subject, predicate, RDF.iri(object)}]

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
