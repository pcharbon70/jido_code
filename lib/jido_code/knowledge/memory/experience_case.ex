defmodule JidoCode.Knowledge.Memory.ExperienceCase do
  @moduledoc "Closed, source-linked, non-authoritative reusable attempt case."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ExperienceTransition
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :revision,
    :repository_iri,
    :repository_scope_iri,
    :experience_graph_iri,
    :repository_version,
    :problem_signature,
    :task_class,
    :plan_phase,
    :environment,
    :dependencies,
    :symptoms,
    :reproduction,
    :inspected_files,
    :inspected_symbols,
    :interventions,
    :disproved_assumptions,
    :terminal_intervention,
    :verification_iris,
    :delayed_outcome,
    :exceptions,
    :limitations,
    :source_event_iris,
    :source_artifact_iris,
    :source_evidence_iris,
    :case_class,
    :effective_at,
    :recorded_at,
    :transition,
    :non_authoritative?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @case_classes ~w[success failure revert flake infrastructure abandoned ambiguous]a
  @task_classes ~w[diagnosis implementation repair review migration evaluation incident]a
  @revision "1.0.0"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec case_classes() :: [atom()]
  def case_classes, do: @case_classes

  @spec new(map()) :: {:ok, struct()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes, [:repository_iri, :repository_scope_iri]),
         {:ok, :experience} <- GraphRegistry.identify(attributes[:experience_graph_iri]),
         true <- safe_revision?(attributes[:repository_version]),
         true <- digest?(attributes[:problem_signature]),
         true <- attributes[:task_class] in @task_classes,
         true <- safe_string?(attributes[:plan_phase], 64),
         {:ok, environment} <- environment(attributes[:environment]),
         {:ok, dependencies} <- dependencies(attributes[:dependencies]),
         {:ok, symptoms} <- texts(attributes[:symptoms], 20, 512, false),
         {:ok, reproduction} <- texts(attributes[:reproduction], 20, 512, false),
         {:ok, files} <- texts(attributes[:inspected_files], 100, 512, true),
         {:ok, symbols} <- texts(attributes[:inspected_symbols], 100, 512, true),
         {:ok, interventions} <- texts(attributes[:interventions], 30, 1_024, false),
         {:ok, disproved} <- texts(attributes[:disproved_assumptions], 30, 1_024, true),
         true <- safe_string?(attributes[:terminal_intervention], 1_024),
         {:ok, verification} <- iri_list(attributes[:verification_iris], 50, false),
         {:ok, delayed} <-
           delayed_outcome(attributes[:delayed_outcome], attributes[:effective_at]),
         {:ok, exceptions} <- texts(attributes[:exceptions], 30, 1_024, true),
         {:ok, limitations} <- texts(attributes[:limitations], 30, 1_024, true),
         {:ok, events} <- iri_list(attributes[:source_event_iris], 200, false),
         {:ok, artifacts} <- iri_list(attributes[:source_artifact_iris], 100, true),
         {:ok, evidence} <- iri_list(attributes[:source_evidence_iris], 100, false),
         true <- attributes[:case_class] in @case_classes,
         %DateTime{} = effective_at <- attributes[:effective_at],
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         true <- DateTime.compare(effective_at, recorded_at) in [:lt, :eq],
         {:ok, iri} <- identity(attributes),
         {:ok, transition} <- initial_transition(iri, attributes) do
      {:ok,
       struct!(__MODULE__,
         iri: iri,
         revision: @revision,
         repository_iri: attributes.repository_iri,
         repository_scope_iri: attributes.repository_scope_iri,
         experience_graph_iri: attributes.experience_graph_iri,
         repository_version: attributes.repository_version,
         problem_signature: attributes.problem_signature,
         task_class: attributes.task_class,
         plan_phase: attributes.plan_phase,
         environment: environment,
         dependencies: dependencies,
         symptoms: symptoms,
         reproduction: reproduction,
         inspected_files: files,
         inspected_symbols: symbols,
         interventions: interventions,
         disproved_assumptions: disproved,
         terminal_intervention: attributes.terminal_intervention,
         verification_iris: verification,
         delayed_outcome: delayed,
         exceptions: exceptions,
         limitations: limitations,
         source_event_iris: events,
         source_artifact_iris: artifacts,
         source_evidence_iris: evidence,
         case_class: attributes.case_class,
         effective_at: DateTime.truncate(effective_at, :microsecond),
         recorded_at: DateTime.truncate(recorded_at, :microsecond),
         transition: transition,
         non_authoritative?: true
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec statements(struct()) :: [tuple()]
  def statements(%__MODULE__{} = experience) do
    [
      {experience.iri, @rdf_type, RDF.iri(@jf <> "ExperienceCase")},
      {experience.iri, @jf <> "about", RDF.iri(experience.repository_iri)},
      {experience.iri, @jf <> "version", RDF.XSD.String.new(experience.revision)},
      {experience.iri, @jf <> "repositoryVersion",
       RDF.XSD.String.new(experience.repository_version)},
      {experience.iri, @jf <> "problemSignature",
       RDF.XSD.String.new(experience.problem_signature)},
      {experience.iri, @jf <> "taskClass", concept(experience.task_class)},
      {experience.iri, @jf <> "planPhase", RDF.XSD.String.new(experience.plan_phase)},
      {experience.iri, @jf <> "caseClass", concept(experience.case_class)},
      {experience.iri, @jf <> "terminalIntervention",
       RDF.XSD.String.new(experience.terminal_intervention)},
      {experience.iri, @jf <> "effectiveAt", RDF.XSD.DateTime.new(experience.effective_at)},
      {experience.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(experience.recorded_at)},
      {experience.iri, @jf <> "nonAuthoritative", RDF.XSD.Boolean.new(true)},
      {experience.iri, @jf <> "lifecycleTransition", RDF.iri(experience.transition.iri)}
    ] ++
      ExperienceTransition.statements(experience.transition) ++
      iri_statements(experience.iri, @jf <> "sourceEvent", experience.source_event_iris) ++
      iri_statements(experience.iri, @jf <> "sourceArtifact", experience.source_artifact_iris) ++
      iri_statements(experience.iri, @jf <> "evidenceSource", experience.source_evidence_iris) ++
      iri_statements(experience.iri, @jf <> "verification", experience.verification_iris) ++
      literal_statements(experience.iri, @jf <> "symptom", experience.symptoms) ++
      literal_statements(experience.iri, @jf <> "reproductionStep", experience.reproduction) ++
      literal_statements(experience.iri, @jf <> "inspectedFile", experience.inspected_files) ++
      literal_statements(experience.iri, @jf <> "inspectedSymbol", experience.inspected_symbols) ++
      literal_statements(experience.iri, @jf <> "intervention", experience.interventions) ++
      literal_statements(
        experience.iri,
        @jf <> "disprovedAssumption",
        experience.disproved_assumptions
      ) ++
      literal_statements(experience.iri, @jf <> "exception", experience.exceptions) ++
      literal_statements(experience.iri, @jf <> "limitation", experience.limitations) ++
      environment_statements(experience) ++
      dependency_statements(experience) ++
      delayed_statements(experience)
  end

  defp initial_transition(iri, attributes) do
    ExperienceTransition.new(%{
      case_iri: iri,
      prior_state: nil,
      next_state: :candidate,
      revision: 0,
      expected_predecessor: nil,
      actor_iri: attributes[:actor_iri],
      cause_iri: attributes[:cause_iri],
      reason: "create source-linked experience candidate",
      recorded_at: attributes[:recorded_at]
    })
  end

  defp identity(attributes) do
    ResourceIdentity.deterministic(
      :experience_case,
      :erlang.term_to_binary(
        Map.take(attributes, [
          :repository_iri,
          :repository_version,
          :problem_signature,
          :task_class,
          :plan_phase,
          :environment,
          :dependencies,
          :source_event_iris,
          :source_artifact_iris,
          :source_evidence_iris,
          :case_class,
          :effective_at
        ]),
        [:deterministic]
      )
    )
  end

  defp environment(%{framework: framework, version: version, os: os, runtime: runtime} = value)
       when map_size(value) == 4 do
    if Enum.all?([framework, version, os, runtime], &safe_string?(&1, 128)),
      do: {:ok, value},
      else: :error
  end

  defp environment(_value), do: :error

  defp dependencies(values) when is_list(values) and length(values) <= 100 do
    if Enum.all?(values, fn
         %{name: name, version: version} = value when map_size(value) == 2 ->
           safe_string?(name, 128) and safe_string?(version, 128)

         _invalid ->
           false
       end) do
      {:ok, Enum.sort_by(values, &{&1.name, &1.version})}
    else
      :error
    end
  end

  defp dependencies(_values), do: :error

  defp delayed_outcome(
         %{outcome: outcome, evidence_iri: evidence_iri, observed_at: %DateTime{} = observed_at} =
           value,
         %DateTime{} = effective_at
       )
       when map_size(value) == 3 and outcome in @case_classes do
    if ResourceIdentity.validate(evidence_iri) == :ok and
         DateTime.compare(observed_at, effective_at) in [:lt, :eq],
       do: {:ok, %{value | observed_at: DateTime.truncate(observed_at, :microsecond)}},
       else: :error
  end

  defp delayed_outcome(_value, _effective_at), do: :error

  defp resources(attributes, keys) do
    if Enum.all?(keys, &(ResourceIdentity.validate(attributes[&1]) == :ok)) and
         ResourceIdentity.validate(attributes[:actor_iri]) == :ok and
         ResourceIdentity.validate(attributes[:cause_iri]) == :ok,
       do: :ok,
       else: invalid()
  end

  defp iri_list(values, maximum, empty?) when is_list(values) and length(values) <= maximum do
    if (empty? or values != []) and length(values) == length(Enum.uniq(values)) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, Enum.sort(values)},
       else: :error
  end

  defp iri_list(_values, _maximum, _empty?), do: :error

  defp texts(values, maximum, bytes, empty?) when is_list(values) and length(values) <= maximum do
    if (empty? or values != []) and length(values) == length(Enum.uniq(values)) and
         Enum.all?(values, &safe_string?(&1, bytes)),
       do: {:ok, Enum.sort(values)},
       else: :error
  end

  defp texts(_values, _maximum, _bytes, _empty?), do: :error

  defp safe_revision?(value), do: safe_string?(value, 128)
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp safe_string?(value, maximum) when is_binary(value) do
    byte_size(value) >= 1 and byte_size(value) <= maximum and
      not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
  end

  defp safe_string?(_value, _maximum), do: false
  defp concept(value), do: RDF.iri(@concept <> Macro.camelize(to_string(value)))

  defp iri_statements(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, RDF.iri(&1)})

  defp literal_statements(subject, predicate, values),
    do: Enum.map(values, &{subject, predicate, RDF.XSD.String.new(&1)})

  defp environment_statements(experience) do
    Enum.map(experience.environment, fn {key, value} ->
      {experience.iri, @jf <> "environment" <> Macro.camelize(to_string(key)),
       RDF.XSD.String.new(value)}
    end)
  end

  defp dependency_statements(experience) do
    Enum.map(experience.dependencies, fn dependency ->
      {experience.iri, @jf <> "dependency",
       RDF.XSD.String.new(dependency.name <> "@" <> dependency.version)}
    end)
  end

  defp delayed_statements(experience) do
    delayed = experience.delayed_outcome

    [
      {experience.iri, @jf <> "delayedOutcome", concept(delayed.outcome)},
      {experience.iri, @jf <> "delayedOutcomeEvidence", RDF.iri(delayed.evidence_iri)},
      {experience.iri, @jf <> "delayedOutcomeObservedAt",
       RDF.XSD.DateTime.new(delayed.observed_at)}
    ]
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :experience_case)}
end
