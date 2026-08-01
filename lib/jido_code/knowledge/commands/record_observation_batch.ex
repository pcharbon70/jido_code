defmodule JidoCode.Knowledge.Commands.RecordObservationBatch do
  @moduledoc """
  Builds one immutable observation-batch semantic command.

  The command guards the accepted active enrollment transition in the catalog,
  creates a closed graph atomically, and emits only reviewed direct statements,
  observed/asserted claims, and an optional exact Git snapshot anchor.
  """

  alias JidoCode.Knowledge.Claims
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @allowed_predicates MapSet.new([
                        @jf <> "defaultBranch",
                        @jf <> "visibility",
                        @jf <> "archived",
                        @jf <> "fork",
                        @jf <> "locatorState",
                        @jf <> "refName",
                        @jf <> "commitIdentity",
                        @jf <> "treeIdentity",
                        @jf <> "status",
                        @jf <> "conclusion",
                        @jf <> "permission",
                        @jf <> "providerRevision",
                        @jf <> "available",
                        @jf <> "dependency"
                      ])
  @max_assertions 500

  @spec build(map(), keyword()) ::
          {:ok,
           %{
             command: CommandEnvelope.t(),
             graph_iri: String.t(),
             batch_iri: String.t(),
             activity_iri: String.t(),
             claim_iris: [String.t()],
             snapshot_iri: String.t() | nil
           }}
          | {:error, Error.t()}
  def build(attributes, options \\ [])

  def build(attributes, options) when is_map(attributes) and is_list(options) do
    with :ok <- validate_resources(attributes),
         :ok <- active_enrollment(attributes[:enrollment]),
         true <- attributes[:source] in [:poll, :webhook],
         true <- delivery_identity?(attributes[:delivery_identity]),
         %DateTime{} = retrieved_at <- attributes[:retrieved_at],
         true <- optional_time?(attributes[:source_time]),
         true <- valid_text?(attributes[:adapter_version], 128),
         {:ok, response_digests} <- digest_list(attributes[:response_digests]),
         :ok <- optional_digest(attributes[:request_digest]),
         {:ok, coverage} <- text_list(attributes[:coverage], 100, 128),
         {:ok, missing} <- text_list(attributes[:missing], 100, 128),
         {:ok, limitations} <- text_list(attributes[:limitations], 50, 256),
         {:ok, warnings} <- text_list(attributes[:warnings], 50, 256),
         :ok <- optional_resource(attributes[:previous_batch_iri]),
         {:ok, batch_iri} <-
           ResourceIdentity.observation_batch(
             attributes[:enrollment].enrollment_iri,
             Atom.to_string(attributes[:source]),
             attributes[:delivery_identity]
           ),
         {:ok, activity_iri} <- ResourceIdentity.observation_activity(batch_iri),
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(
             :command_request,
             "RecordObservationBatch\n" <> batch_iri
           ),
         {:ok, graph_iri} <-
           GraphRegistry.graph_iri(:observation_batch, %{
             repository: attributes[:repository_iri],
             batch: batch_iri
           }),
         {:ok, metadata} <-
           GraphMetadata.new(graph_iri, %{
             owner_scope: attributes[:repository_scope_iri],
             ontology_version: "https://jido.run/ontology/release/1.0.0",
             creation_activity: command_iri,
             created_at: retrieved_at,
             lifecycle_state: :closed,
             completeness_state: :complete,
             closed_at: retrieved_at,
             graph_revision: 1
           }),
         {:ok, metadata_statements} <- GraphMetadata.quads(metadata),
         {:ok, assertions, claim_iris} <-
           compile_assertions(
             attributes[:assertions],
             Map.get(attributes, :prior_claims, []),
             batch_iri,
             activity_iri,
             graph_iri,
             retrieved_at
           ),
         {:ok, snapshot_statements, snapshot_iri} <-
           snapshot_statements(
             attributes[:snapshot],
             attributes[:repository_iri],
             batch_iri,
             activity_iri,
             retrieved_at
           ),
         {:ok, completeness_iri} <-
           ResourceIdentity.provider_object(batch_iri, :completeness, "observation-batch"),
         additions <-
           metadata_statements ++
             batch_statements(
               attributes,
               batch_iri,
               activity_iri,
               graph_iri,
               completeness_iri,
               response_digests,
               coverage,
               missing,
               limitations,
               warnings,
               retrieved_at
             ) ++ assertions ++ snapshot_statements,
         {:ok, command} <-
           command(
             attributes,
             command_iri,
             graph_iri,
             batch_iri,
             metadata,
             additions,
             options
           ) do
      {:ok,
       %{
         command: command,
         graph_iri: graph_iri,
         batch_iri: batch_iri,
         activity_iri: activity_iri,
         claim_iris: claim_iris,
         snapshot_iri: snapshot_iri
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_observation_batch)
    end
  rescue
    _error -> invalid(:record_observation_batch)
  end

  def build(_attributes, _options), do: invalid(:record_observation_batch)

  defp command(attributes, command_iri, graph_iri, batch_iri, metadata, additions, options) do
    enrollment = attributes.enrollment
    catalog_graph = enrollment.catalog_graph_iri

    CommandEnvelope.new(
      %{
        command_type: "RecordObservationBatch",
        command_version: "1.1.0",
        command_iri: command_iri,
        principal_iri: attributes[:principal_iri],
        actor_iri: attributes[:actor_iri],
        delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
        delegation_iri: Map.get(attributes, :delegation_iri),
        scope_iri: attributes[:repository_scope_iri],
        idempotency_key: attributes[:delivery_identity],
        correlation_iri: attributes[:correlation_iri],
        causation_iri: attributes[:causation_iri],
        ontology_version: "1.0.0",
        shape_version: "1.0.0",
        expected_dataset_revision: attributes[:expected_dataset_revision],
        expected_graph_revisions: %{
          graph_iri => 0,
          catalog_graph => enrollment.catalog_revision
        },
        reason: attributes[:reason],
        payload: %{
          guards: [
            {:subject_present, catalog_graph, enrollment.enrollment_iri},
            {:triple_present, catalog_graph, enrollment.current_transition,
             @jf <> "transitionSubject", RDF.iri(enrollment.enrollment_iri)},
            {:triple_present, catalog_graph, enrollment.current_transition, @jf <> "nextState",
             RDF.iri(@concept <> "EnrollmentActive")},
            {:transition_endpoint, catalog_graph, enrollment.enrollment_iri,
             enrollment.current_transition},
            {:subject_absent, graph_iri, batch_iri}
          ],
          changes: [
            %{
              family: :observation_batch,
              graph_iri: graph_iri,
              operation: :create,
              metadata: metadata,
              additions: additions,
              supersessions: [],
              invalidations: [],
              removals: []
            }
          ]
        }
      },
      options
    )
  end

  defp batch_statements(
         attributes,
         batch,
         activity,
         graph,
         completeness,
         response_digests,
         coverage,
         missing,
         limitations,
         warnings,
         retrieved_at
       ) do
    enrollment = attributes.enrollment
    status = completeness_status(coverage, missing)

    [
      {activity, @rdf_type, RDF.iri(@jf <> "ObservationActivity")},
      {activity, @prov <> "wasAssociatedWith", RDF.iri(attributes.actor_iri)},
      {activity, @prov <> "used", RDF.iri(attributes.locator_iri)},
      {activity, @prov <> "generated", RDF.iri(batch)},
      {activity, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(retrieved_at)},
      {activity, @jf <> "adapter", RDF.iri(attributes.adapter_iri)},
      {activity, @jf <> "adapterVersion", RDF.XSD.String.new(attributes.adapter_version)},
      {batch, @rdf_type, RDF.iri(@jf <> "ObservationBatch")},
      {batch, @jf <> "about", RDF.iri(attributes.repository_iri)},
      {batch, @jf <> "validFor", RDF.iri(enrollment.enrollment_iri)},
      {batch, @jf <> "locatedBy", RDF.iri(attributes.locator_iri)},
      {batch, @jf <> "sourceActivity", RDF.iri(activity)},
      {batch, @jf <> "graphScope", RDF.iri(graph)},
      {batch, @jf <> "recordedAt", RDF.XSD.DateTime.new(retrieved_at)},
      {batch, @jf <> "sourceKind", RDF.XSD.String.new(Atom.to_string(attributes.source))},
      {batch, @jf <> "deliveryIdentity", RDF.XSD.String.new(attributes.delivery_identity)},
      {batch, @jf <> "completenessState", RDF.iri(@concept <> status)},
      {completeness, @rdf_type, RDF.iri(@jf <> "CompletenessAssertion")},
      {completeness, @jf <> "about", RDF.iri(enrollment.enrollment_iri)},
      {completeness, @jf <> "sourceActivity", RDF.iri(activity)},
      {completeness, @jf <> "completenessState", RDF.iri(@concept <> status)},
      {completeness, @jf <> "recordedAt", RDF.XSD.DateTime.new(retrieved_at)}
    ]
    |> maybe_add_time(batch, @jf <> "sourceObservedAt", attributes[:source_time])
    |> maybe_add_resource(batch, @prov <> "wasDerivedFrom", attributes[:previous_batch_iri])
    |> maybe_add_digest(activity, "request", attributes[:request_digest])
    |> add_values(activity, @jf <> "responseDigest", response_digests)
    |> add_values(completeness, @jf <> "coverage", coverage)
    |> add_values(completeness, @jf <> "missingCoverage", missing)
    |> add_values(completeness, @jf <> "limitation", limitations)
    |> add_values(completeness, @jf <> "warning", warnings)
  end

  defp compile_assertions(values, prior_claims, batch, activity, graph, recorded_at)
       when is_list(values) and length(values) <= @max_assertions and is_list(prior_claims) and
              length(prior_claims) <= @max_assertions do
    with {:ok, normalized} <- normalize_assertions(values, batch),
         {:ok, prior_claims} <- normalize_prior_claims(prior_claims),
         contradictions <- contradiction_index(normalized, prior_claims),
         {:ok, statements, claims} <-
           Enum.reduce_while(normalized, {:ok, [], []}, fn assertion, {:ok, acc, claim_iris} ->
             case compile_assertion(
                    assertion,
                    contradictions,
                    activity,
                    graph,
                    recorded_at
                  ) do
               {:ok, additions, nil} ->
                 {:cont, {:ok, additions ++ acc, claim_iris}}

               {:ok, additions, claim_iri} ->
                 {:cont, {:ok, additions ++ acc, [claim_iri | claim_iris]}}

               {:error, %Error{} = error} ->
                 {:halt, {:error, error}}
             end
           end) do
      {:ok, Enum.reverse(statements), Enum.reverse(claims)}
    end
  end

  defp compile_assertions(_values, _prior, _batch, _activity, _graph, _recorded_at),
    do: invalid(:observation_assertions)

  defp normalize_assertions(values, batch) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      with true <- is_map(value),
           mode when mode in [:direct, :claim] <- Map.get(value, :mode, :claim),
           :ok <- ResourceIdentity.validate(value[:subject]),
           true <- MapSet.member?(@allowed_predicates, value[:predicate]),
           {_, _, _} = triple <-
             RDF.Triple.new({value[:subject], value[:predicate], value[:object]}),
           true <- valid_statement?(triple),
           {:ok, claim_iri} <- claim_identity(mode, batch, triple),
           true <- Map.get(value, :epistemic_state, :observed) in [:observed, :asserted],
           :ok <- resource_list(Map.get(value, :contradicts, [])),
           :ok <- resource_list(Map.get(value, :supports, [])),
           :ok <- resource_list(Map.get(value, :supersedes, [])) do
        normalized =
          value
          |> Map.put(:mode, mode)
          |> Map.put(:triple, triple)
          |> Map.put(:claim_iri, claim_iri)

        {:cont, {:ok, [normalized | acc]}}
      else
        {:error, %Error{} = error} -> {:halt, {:error, error}}
        _invalid -> {:halt, invalid(:observation_assertion)}
      end
    end)
    |> case do
      {:ok, assertions} -> {:ok, Enum.reverse(assertions)}
      error -> error
    end
  rescue
    _error -> invalid(:observation_assertion)
  end

  defp compile_assertion(
         %{mode: :direct, triple: triple} = assertion,
         _links,
         _activity,
         _graph,
         _time
       ) do
    if direct_eligible?(assertion), do: {:ok, [triple], nil}, else: invalid(:direct_observation)
  end

  defp compile_assertion(assertion, contradiction_index, activity, graph, recorded_at) do
    links =
      Map.get(assertion, :contradicts, []) ++
        Map.get(contradiction_index, assertion.claim_iri, [])

    {subject, predicate, object} = assertion.triple

    Claims.build(%{
      claim_iri: assertion.claim_iri,
      graph_iri: graph,
      subject: RDF.IRI.to_string(subject),
      predicate: RDF.IRI.to_string(predicate),
      object: object,
      source_activity: activity,
      epistemic_state: Map.get(assertion, :epistemic_state, :observed),
      recorded_at: recorded_at,
      source_observed_at: Map.get(assertion, :source_observed_at),
      confidence_value: Map.get(assertion, :confidence_value),
      confidence_band: Map.get(assertion, :confidence_band),
      valid_from: Map.get(assertion, :valid_from),
      valid_to: Map.get(assertion, :valid_to),
      supports: Map.get(assertion, :supports, []),
      contradicts: Enum.uniq(links),
      supersedes: Map.get(assertion, :supersedes, [])
    })
    |> case do
      {:ok, claim} -> {:ok, claim.quads, assertion.claim_iri}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp snapshot_statements(nil, _repository, _batch, _activity, _retrieved_at),
    do: {:ok, [], nil}

  defp snapshot_statements(snapshot, repository, batch, activity, retrieved_at)
       when is_map(snapshot) do
    with format when format in [:sha1, :sha256] <- snapshot[:object_format],
         {:ok, commit_iri} <- ResourceIdentity.git_object(format, snapshot[:commit_sha]),
         {:ok, tree_iri} <- ResourceIdentity.git_object(format, snapshot[:tree_sha]),
         {:ok, snapshot_iri} <-
           ResourceIdentity.repository_snapshot(repository, format, snapshot[:tree_sha]),
         true <- is_list(snapshot[:parents]) and length(snapshot[:parents]) <= 100,
         {:ok, parents} <- parent_iris(format, snapshot[:parents]),
         true <- valid_text?(snapshot[:ref], 256),
         {:ok, manifests} <- text_list(Map.get(snapshot, :manifests, []), 100, 256),
         {:ok, languages} <- text_list(Map.get(snapshot, :languages, []), 50, 64) do
      statements = [
        {snapshot_iri, @rdf_type, RDF.iri(@jf <> "RepositorySnapshot")},
        {snapshot_iri, @jf <> "about", RDF.iri(repository)},
        {snapshot_iri, @jf <> "commitIdentity", RDF.iri(commit_iri)},
        {snapshot_iri, @jf <> "treeIdentity", RDF.iri(tree_iri)},
        {snapshot_iri, @jf <> "refName", RDF.XSD.String.new(snapshot[:ref])},
        {snapshot_iri, @jf <> "sourceActivity", RDF.iri(activity)},
        {snapshot_iri, @prov <> "wasGeneratedBy", RDF.iri(activity)},
        {snapshot_iri, @jf <> "sourceObservedAt", RDF.XSD.DateTime.new(retrieved_at)},
        {snapshot_iri, @jf <> "analyzerReadiness", RDF.iri(@concept <> "Pending")},
        {batch, @prov <> "generated", RDF.iri(snapshot_iri)}
      ]

      statements =
        statements
        |> add_iri_values(snapshot_iri, @jf <> "parentCommit", parents)
        |> add_values(snapshot_iri, @jf <> "manifest", manifests)
        |> add_values(snapshot_iri, @jf <> "language", languages)

      {:ok, statements, snapshot_iri}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_snapshot)
    end
  end

  defp snapshot_statements(_snapshot, _repository, _batch, _activity, _retrieved_at),
    do: invalid(:repository_snapshot)

  defp validate_resources(attributes) do
    Enum.reduce_while(
      [
        :repository_iri,
        :repository_scope_iri,
        :locator_iri,
        :actor_iri,
        :adapter_iri,
        :principal_iri,
        :correlation_iri,
        :causation_iri
      ],
      :ok,
      fn key, :ok ->
        case ResourceIdentity.validate(attributes[key]) do
          :ok -> {:cont, :ok}
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end
      end
    )
  end

  defp active_enrollment(%{
         enrollment_iri: enrollment,
         current_transition: transition,
         current_state: :active,
         admission: :allowed,
         catalog_graph_iri: graph,
         catalog_revision: revision
       }) do
    with :ok <- ResourceIdentity.validate(enrollment),
         :ok <- ResourceIdentity.validate(transition),
         {:ok, :factory_catalog} <- GraphRegistry.identify(graph),
         true <- is_integer(revision) and revision > 0 do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:conflict, :observation_enrollment_inactive)}
    end
  end

  defp active_enrollment(_enrollment),
    do: {:error, Error.new(:conflict, :observation_enrollment_inactive)}

  defp valid_statement?({_, _, %RDF.Literal{} = literal}) do
    lexical = RDF.Literal.lexical(literal)

    byte_size(lexical) <= 2_048 and
      not Regex.match?(~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u, lexical)
  end

  defp valid_statement?({_, _, %RDF.IRI{value: value}}), do: RDF.IRI.valid?(value)
  defp valid_statement?(_triple), do: false

  defp claim_identity(:direct, _batch, _triple), do: {:ok, nil}
  defp claim_identity(:claim, batch, triple), do: ResourceIdentity.observed_claim(batch, triple)

  defp direct_eligible?(assertion) do
    empty_keys = [
      :confidence_value,
      :confidence_band,
      :valid_from,
      :valid_to,
      :source_observed_at,
      :supports,
      :contradicts,
      :supersedes
    ]

    not Map.get(assertion, :consequential?, false) and
      not Map.get(assertion, :disputable?, false) and
      Enum.all?(empty_keys, &(Map.get(assertion, &1) in [nil, []]))
  end

  defp contradiction_index(assertions, prior_claims) do
    assertions
    |> Enum.filter(&(&1.mode == :claim))
    |> Enum.group_by(fn assertion ->
      {subject, predicate, _object} = assertion.triple
      {RDF.IRI.to_string(subject), RDF.IRI.to_string(predicate)}
    end)
    |> Enum.reduce(%{}, fn {key, group}, acc ->
      Enum.reduce(group, acc, fn assertion, inner ->
        new_conflicts =
          group
          |> Enum.reject(&same_object?(&1.triple, assertion.triple))
          |> Enum.map(& &1.claim_iri)

        prior_conflicts =
          prior_claims
          |> Enum.filter(&(&1.key == key and not same_object?(&1.triple, assertion.triple)))
          |> Enum.map(& &1.claim_iri)

        Map.put(inner, assertion.claim_iri, Enum.uniq(new_conflicts ++ prior_conflicts))
      end)
    end)
  end

  defp normalize_prior_claims(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      with true <- is_map(value),
           :ok <- ResourceIdentity.validate(value[:claim_iri]),
           :ok <- ResourceIdentity.validate(value[:subject]),
           true <- MapSet.member?(@allowed_predicates, value[:predicate]),
           {_, _, _} = triple <-
             RDF.Triple.new({value[:subject], value[:predicate], value[:object]}),
           true <- valid_statement?(triple) do
        key = {value[:subject], value[:predicate]}
        {:cont, {:ok, [%{claim_iri: value[:claim_iri], key: key, triple: triple} | acc]}}
      else
        {:error, %Error{} = error} -> {:halt, {:error, error}}
        _invalid -> {:halt, invalid(:prior_observation_claim)}
      end
    end)
    |> case do
      {:ok, claims} -> {:ok, Enum.reverse(claims)}
      error -> error
    end
  rescue
    _error -> invalid(:prior_observation_claim)
  end

  defp same_object?({_, _, left}, {_, _, right}), do: RDF.Term.equal_value?(left, right)

  defp parent_iris(format, values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case ResourceIdentity.git_object(format, value) do
        {:ok, iri} -> {:cont, {:ok, [iri | acc]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, iris} -> {:ok, Enum.reverse(iris)}
      error -> error
    end
  end

  defp resource_list(values) when is_list(values) and length(values) <= 100 do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: :ok,
      else: invalid(:observation_claim_links)
  end

  defp resource_list(_values), do: invalid(:observation_claim_links)

  defp digest_list(values) when is_list(values) and length(values) in 1..500 do
    if Enum.all?(values, &delivery_identity?/1),
      do: {:ok, Enum.uniq(values)},
      else: invalid(:observation_digests)
  end

  defp digest_list(_values), do: invalid(:observation_digests)

  defp optional_digest(nil), do: :ok
  defp optional_digest(value), do: if(delivery_identity?(value), do: :ok, else: invalid(:digest))
  defp delivery_identity?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp optional_time?(nil), do: true
  defp optional_time?(%DateTime{}), do: true
  defp optional_time?(_time), do: false
  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: ResourceIdentity.validate(value)

  defp text_list(values, max_count, max_bytes)
       when is_list(values) and length(values) <= max_count do
    values = Enum.map(values, &to_string/1)

    if Enum.all?(values, &valid_text?(&1, max_bytes)),
      do: {:ok, Enum.uniq(values)},
      else: invalid(:observation_text)
  end

  defp text_list(_values, _count, _bytes), do: invalid(:observation_text)

  defp valid_text?(value, max_bytes) do
    is_binary(value) and byte_size(value) in 1..max_bytes and
      not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
  end

  defp completeness_status(_coverage, []), do: "Complete"
  defp completeness_status([], _missing), do: "Unknown"
  defp completeness_status(_coverage, _missing), do: "Partial"

  defp maybe_add_time(statements, _subject, _predicate, nil), do: statements

  defp maybe_add_time(statements, subject, predicate, %DateTime{} = time),
    do: [{subject, predicate, RDF.XSD.DateTime.new(time)} | statements]

  defp maybe_add_resource(statements, _subject, _predicate, nil), do: statements

  defp maybe_add_resource(statements, subject, predicate, resource),
    do: [{subject, predicate, RDF.iri(resource)} | statements]

  defp maybe_add_digest(statements, _subject, _kind, nil), do: statements

  defp maybe_add_digest(statements, subject, kind, value),
    do: [{subject, @jf <> "requestDigest", RDF.XSD.String.new(kind <> ":" <> value)} | statements]

  defp add_values(statements, subject, predicate, values) do
    Enum.reduce(values, statements, fn value, acc ->
      [{subject, predicate, RDF.XSD.String.new(value)} | acc]
    end)
  end

  defp add_iri_values(statements, subject, predicate, values) do
    Enum.reduce(values, statements, fn value, acc ->
      [{subject, predicate, RDF.iri(value)} | acc]
    end)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
