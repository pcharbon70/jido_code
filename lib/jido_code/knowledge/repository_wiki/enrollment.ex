defmodule JidoCode.Knowledge.RepositoryWiki.Enrollment do
  @moduledoc "Immutable repository wiki enrollment revisions and fail-closed transitions."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.Transition
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.GenerationProfile
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :repository_iri,
    :tenant_iri,
    :wiki_iri,
    :revision,
    :state,
    :maintenance_mode,
    :generation_mode,
    :preview_mode,
    :generation_profile_iri,
    :read_visibility,
    :accounting_retention,
    :audit_retention,
    :retention_class,
    :cancellation_generation,
    :current_edition_iri,
    :recorded_at
  ]
  defstruct @enforce_keys

  @type state :: :off | :manual | :automatic
  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @states [:off, :manual, :automatic]
  @read_visibility [:hidden, :retained]

  @spec default(String.t(), String.t()) :: {:ok, map()} | {:error, Error.t()}
  def default(repository_iri, tenant_iri) do
    with :ok <- Contract.resource(repository_iri),
         :ok <- Contract.resource(tenant_iri),
         {:ok, wiki_iri} <- ResourceIdentity.repository_wiki(repository_iri) do
      {:ok,
       %{
         configured?: false,
         repository_iri: repository_iri,
         tenant_iri: tenant_iri,
         wiki_iri: wiki_iri,
         revision: nil,
         state: :off,
         maintenance_mode: :off,
         generation_mode: :deterministic_only,
         preview_mode: :disabled,
         generation_profile_iri: nil,
         read_visibility: :hidden,
         retained_readable?: false,
         product_available?: false,
         generation_allowed?: false,
         cancellation_generation: 0,
         current_edition_iri: nil
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    profile = Map.get(attributes, :generation_profile)

    with :ok <- Contract.resource(attributes[:repository_iri]),
         :ok <- Contract.resource(attributes[:tenant_iri]),
         {:ok, wiki_iri} <- ResourceIdentity.repository_wiki(attributes[:repository_iri]),
         revision when is_integer(revision) and revision >= 0 <- attributes[:revision],
         state when state in @states <- attributes[:state],
         :ok <- compatible_profile(state, profile),
         read_visibility when read_visibility in @read_visibility <-
           attributes[:read_visibility],
         preview_mode when preview_mode in [:disabled, :allowed] <- attributes[:preview_mode],
         true <- preview_compatible?(state, profile, preview_mode),
         true <- attributes[:generation_mode] == :deterministic_only,
         cancellation when is_integer(cancellation) and cancellation >= 0 <-
           attributes[:cancellation_generation],
         :ok <- Contract.optional_resource(attributes[:current_edition_iri]),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         true <- recorded_at == DateTime.truncate(recorded_at, :microsecond),
         profile_iri <- profile_iri(profile),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :repository_wiki_enrollment,
             Enum.join(
               [
                 attributes.repository_iri,
                 Integer.to_string(revision),
                 Atom.to_string(state),
                 profile_iri || "off"
               ],
               "\n"
             )
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         repository_iri: attributes.repository_iri,
         tenant_iri: attributes.tenant_iri,
         wiki_iri: wiki_iri,
         revision: revision,
         state: state,
         maintenance_mode: state,
         generation_mode: :deterministic_only,
         preview_mode: preview_mode,
         generation_profile_iri: profile_iri,
         read_visibility: read_visibility,
         accounting_retention: :wiki_accounting,
         audit_retention: :wiki_audit,
         retention_class: :wiki_current,
         cancellation_generation: cancellation,
         current_edition_iri: attributes[:current_edition_iri],
         recorded_at: recorded_at
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_enrollment)
    end
  rescue
    _error -> invalid(:repository_wiki_enrollment)
  end

  def new(_attributes), do: invalid(:repository_wiki_enrollment)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = enrollment) do
    [
      {enrollment.iri, @rdf_type, RDF.iri(@jf <> "RepositoryWikiEnrollment")},
      {enrollment.iri, @jf <> "repositoryScope", RDF.iri(enrollment.repository_iri)},
      {enrollment.iri, @jf <> "tenantScope", RDF.iri(enrollment.tenant_iri)},
      {enrollment.iri, @jf <> "repositoryWiki", RDF.iri(enrollment.wiki_iri)},
      {enrollment.iri, @jf <> "enrollmentRevision",
       RDF.XSD.NonNegativeInteger.new(enrollment.revision)},
      {enrollment.iri, @jf <> "enrollmentState", RDF.iri(state_concept(enrollment.state))},
      {enrollment.iri, @jf <> "maintenanceMode",
       RDF.iri(state_concept(enrollment.maintenance_mode))},
      {enrollment.iri, @jf <> "generationMode",
       RDF.iri(Contract.concept(:wiki_deterministic_only))},
      {enrollment.iri, @jf <> "previewMode",
       RDF.iri(Contract.concept(preview_concept(enrollment.preview_mode)))},
      {enrollment.iri, @jf <> "wikiReadVisibility",
       RDF.iri(read_visibility_concept(enrollment.read_visibility))},
      {enrollment.iri, @jf <> "wikiAccountingRetention",
       RDF.iri(Contract.concept(:wiki_accounting_retention))},
      {enrollment.iri, @jf <> "wikiAuditRetention",
       RDF.iri(Contract.concept(:wiki_audit_retention))},
      {enrollment.iri, @jf <> "wikiCancellationGeneration",
       RDF.XSD.NonNegativeInteger.new(enrollment.cancellation_generation)},
      {enrollment.iri, @jf <> "wikiRetentionClass",
       RDF.iri(Contract.concept(:wiki_current_retention))},
      {enrollment.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(enrollment.recorded_at)}
      | optional_iri(
          enrollment.iri,
          @jf <> "wikiGenerationProfile",
          enrollment.generation_profile_iri
        ) ++
          optional_iri(
            enrollment.iri,
            @jf <> "currentWikiEdition",
            enrollment.current_edition_iri
          )
    ]
  end

  @spec generation_allowed?(t(), :manual_request | :automatic_reconciliation) :: boolean()
  def generation_allowed?(%__MODULE__{state: :manual}, :manual_request), do: true
  def generation_allowed?(%__MODULE__{state: :automatic}, _trigger), do: true
  def generation_allowed?(%__MODULE__{}, _trigger), do: false

  @spec retained_readable?(t()) :: boolean()
  def retained_readable?(%__MODULE__{} = enrollment),
    do: enrollment.read_visibility == :retained and not is_nil(enrollment.current_edition_iri)

  @spec product_available?(t()) :: boolean()
  def product_available?(%__MODULE__{} = enrollment),
    do: enrollment.state != :off and retained_readable?(enrollment)

  @spec transition_command(
          String.t(),
          String.t(),
          nil | map(),
          state(),
          map(),
          keyword()
        ) :: {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def transition_command(
        repository_iri,
        tenant_iri,
        resolution,
        next_state,
        attributes,
        options \\ []
      )

  def transition_command(
        repository_iri,
        tenant_iri,
        resolution,
        next_state,
        attributes,
        options
      )
      when (is_nil(resolution) or is_map(resolution)) and next_state in @states and
             is_map(attributes) and is_list(options) do
    control_graph = attributes[:control_graph_iri]
    catalog_graph = attributes[:catalog_graph_iri]

    with :ok <- Contract.resource(repository_iri),
         :ok <- Contract.resource(tenant_iri),
         true <- exact_control_graph?(control_graph, repository_iri),
         true <- exact_catalog_graph?(catalog_graph),
         true <- positive_revision?(attributes[:expected_control_revision]),
         true <- positive_revision?(attributes[:expected_catalog_revision]),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         true <- recorded_at == DateTime.truncate(recorded_at, :microsecond),
         {:ok, changes} <-
           build_changes(repository_iri, tenant_iri, resolution, next_state, attributes),
         {:ok, command_iri} <- command_identity(changes.enrollment, changes.transition),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope(command_iri, changes, control_graph, catalog_graph, attributes),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:transition_repository_wiki_enrollment)
    end
  rescue
    _error -> invalid(:transition_repository_wiki_enrollment)
  end

  def transition_command(
        _repository_iri,
        _tenant_iri,
        _resolution,
        _next_state,
        _attributes,
        _options
      ),
      do: invalid(:transition_repository_wiki_enrollment)

  defp build_changes(repository_iri, tenant_iri, nil, next_state, attributes) do
    with {:ok, initial} <-
           new(%{
             repository_iri: repository_iri,
             tenant_iri: tenant_iri,
             revision: 0,
             state: :off,
             generation_profile: nil,
             generation_mode: :deterministic_only,
             preview_mode: :disabled,
             read_visibility: :hidden,
             cancellation_generation: 0,
             current_edition_iri: nil,
             recorded_at: attributes.recorded_at
           }),
         {:ok, initial_transition} <- transition(initial, nil, attributes),
         {:ok, result} <-
           initial_successor(initial, initial_transition, next_state, attributes) do
      {:ok, result}
    end
  end

  defp build_changes(repository_iri, tenant_iri, resolution, next_state, attributes) do
    with true <- resolution[:repository_iri] == repository_iri,
         true <- resolution[:tenant_iri] == tenant_iri,
         state when state in @states <- resolution[:current_state],
         revision when is_integer(revision) and revision >= 0 <- resolution[:current_revision],
         :ok <- Contract.resource(resolution[:current_enrollment_iri]),
         :ok <- Contract.resource(resolution[:current_transition_iri]),
         true <- Transition.allowed_edge?(:repository_wiki_enrollment, state, next_state),
         profile <- Map.get(attributes, :generation_profile),
         cancellation <-
           next_cancellation(
             Map.get(resolution, :cancellation_generation, 0),
             state,
             next_state
           ),
         {:ok, enrollment} <-
           new(%{
             repository_iri: repository_iri,
             tenant_iri: tenant_iri,
             revision: revision + 1,
             state: next_state,
             generation_profile: profile,
             generation_mode: :deterministic_only,
             preview_mode:
               if(next_state == :off,
                 do: :disabled,
                 else: Map.get(attributes, :preview_mode, :disabled)
               ),
             read_visibility: Map.get(attributes, :read_visibility, :retained),
             cancellation_generation: cancellation,
             current_edition_iri: Map.get(resolution, :current_edition_iri),
             recorded_at: attributes.recorded_at
           }),
         {:ok, transition} <- transition(enrollment, resolution, attributes) do
      {:ok,
       %{
         enrollment: enrollment,
         transition: transition,
         additions: statements(enrollment) ++ Transition.statements(transition),
         guards:
           [
             {:subject_present, attributes.control_graph_iri, resolution.current_enrollment_iri},
             {:subject_present, attributes.control_graph_iri, resolution.current_transition_iri},
             {:subject_absent, attributes.control_graph_iri, enrollment.iri}
           ] ++ profile_guard(attributes.catalog_graph_iri, enrollment),
         disabled?: next_state == :off
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_enrollment_transition)
    end
  end

  defp initial_successor(initial, initial_transition, :off, attributes) do
    {:ok,
     %{
       enrollment: initial,
       transition: initial_transition,
       additions: statements(initial) ++ Transition.statements(initial_transition),
       guards: [
         {:subject_absent, attributes.control_graph_iri, initial.wiki_iri},
         {:subject_absent, attributes.control_graph_iri, initial.iri}
       ],
       disabled?: true
     }}
  end

  defp initial_successor(initial, initial_transition, next_state, attributes) do
    resolution = %{
      repository_iri: initial.repository_iri,
      tenant_iri: initial.tenant_iri,
      current_state: :off,
      current_revision: 0,
      current_enrollment_iri: initial.iri,
      current_transition_iri: initial_transition.iri,
      cancellation_generation: 0,
      current_edition_iri: nil
    }

    with {:ok, successor} <-
           build_changes(
             initial.repository_iri,
             initial.tenant_iri,
             resolution,
             next_state,
             attributes
           ) do
      {:ok,
       %{
         successor
         | additions:
             statements(initial) ++
               Transition.statements(initial_transition) ++ successor.additions,
           guards: [
             {:subject_absent, attributes.control_graph_iri, initial.wiki_iri},
             {:subject_absent, attributes.control_graph_iri, initial.iri},
             {:subject_absent, attributes.control_graph_iri, successor.enrollment.iri}
             | profile_guard(attributes.catalog_graph_iri, successor.enrollment)
           ]
       }}
    end
  end

  defp transition(enrollment, nil, attributes) do
    Transition.new(%{
      subject_iri: enrollment.wiki_iri,
      domain: :repository_wiki_enrollment,
      prior_state: nil,
      next_state: :off,
      revision: 0,
      expected_predecessor: nil,
      actor_iri: attributes.actor_iri,
      cause_iri: attributes.causation_iri,
      reason: attributes.reason,
      recorded_at: attributes.recorded_at
    })
  end

  defp transition(enrollment, resolution, attributes) do
    Transition.new(%{
      subject_iri: enrollment.wiki_iri,
      domain: :repository_wiki_enrollment,
      prior_state: resolution.current_state,
      next_state: enrollment.state,
      revision: enrollment.revision,
      expected_predecessor: resolution.current_transition_iri,
      actor_iri: attributes.actor_iri,
      cause_iri: attributes.causation_iri,
      reason: attributes.reason,
      recorded_at: attributes.recorded_at
    })
  end

  defp envelope(command_iri, changes, control_graph, catalog_graph, attributes) do
    %{
      command_type: "TransitionRepositoryWikiEnrollment",
      command_version: Protocol.semantic_version(),
      command_iri: command_iri,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:scope_iri],
      idempotency_key: command_iri,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: Protocol.ontology_version(),
      shape_version: Protocol.ontology_version(),
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: %{
        control_graph => attributes[:expected_control_revision],
        catalog_graph => attributes[:expected_catalog_revision]
      },
      reason: attributes[:reason],
      payload: %{
        changes: [
          %{
            family: :repository_control,
            graph_iri: control_graph,
            operation: :append,
            metadata: %{lifecycle_state: :open},
            additions: changes.additions,
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ],
        guards: changes.guards,
        disable_effects:
          if(changes.disabled?,
            do: [
              :reject_new_compilation,
              :advance_cancellation_fence,
              :request_in_flight_cancellation,
              :release_effect_free_reservations,
              :remove_product_availability,
              :preserve_accounting_and_audit_history
            ],
            else: []
          )
      }
    }
  end

  defp compatible_profile(:off, nil), do: :ok

  defp compatible_profile(:manual, %GenerationProfile{profile_key: :manual_deterministic}),
    do: :ok

  defp compatible_profile(:automatic, %GenerationProfile{
         profile_key: :automatic_deterministic
       }),
       do: :ok

  defp compatible_profile(_state, _profile), do: :error

  defp preview_compatible?(:off, nil, :disabled), do: true

  defp preview_compatible?(state, %GenerationProfile{} = profile, preview_mode)
       when state in [:manual, :automatic],
       do: profile.preview_mode == preview_mode

  defp preview_compatible?(_state, _profile, _preview_mode), do: false

  defp profile_iri(nil), do: nil
  defp profile_iri(%GenerationProfile{iri: iri}), do: iri

  defp profile_guard(_graph, %__MODULE__{generation_profile_iri: nil}), do: []

  defp profile_guard(graph, %__MODULE__{generation_profile_iri: iri}),
    do: [{:subject_present, graph, iri}]

  defp command_identity(enrollment, transition) do
    ResourceIdentity.deterministic(
      :command_request,
      Enum.join([enrollment.iri, transition.iri, "enrollment-transition"], "\n")
    )
  end

  defp next_cancellation(value, prior, :off)
       when is_integer(value) and value >= 0 and prior != :off,
       do: value + 1

  defp next_cancellation(value, _prior, _next) when is_integer(value) and value >= 0,
    do: value

  defp positive_revision?(value), do: is_integer(value) and value > 0

  defp exact_control_graph?(graph, repository_iri) do
    case GraphRegistry.graph_iri(:repository_control, %{repository: repository_iri}) do
      {:ok, expected} -> expected == graph
      {:error, %Error{}} -> false
    end
  end

  defp exact_catalog_graph?(graph) do
    case GraphRegistry.graph_iri(:factory_catalog, %{}) do
      {:ok, expected} -> expected == graph
      {:error, %Error{}} -> false
    end
  end

  defp state_concept(:off), do: Contract.concept(:wiki_off)
  defp state_concept(:manual), do: Contract.concept(:wiki_manual)
  defp state_concept(:automatic), do: Contract.concept(:wiki_automatic)
  defp preview_concept(:disabled), do: :wiki_preview_disabled
  defp preview_concept(:allowed), do: :wiki_preview_allowed
  defp read_visibility_concept(:hidden), do: Contract.concept(:wiki_read_hidden)
  defp read_visibility_concept(:retained), do: Contract.concept(:wiki_read_retained)

  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, iri), do: [{subject, predicate, RDF.iri(iri)}]

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
