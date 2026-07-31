defmodule JidoCode.Knowledge.Bootstrap do
  @moduledoc """
  One-time local authority initialization executed inside `Writer`.

  The operator token is checked in memory and never enters RDF, receipts,
  operation metadata, logs, or returned projections.
  """

  alias JidoCode.Knowledge.AuditPolicy
  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Validation.Validator
  alias JidoCode.Knowledge.WriteBatch

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_activity "http://www.w3.org/ns/prov#Activity"
  @prov_associated "http://www.w3.org/ns/prov#wasAssociatedWith"
  @prov_generated_at "http://www.w3.org/ns/prov#generatedAtTime"
  @all_scopes "https://jido.run/ontology/concept/AllScopes"
  @valid_to ~U[9999-12-31 23:59:59Z]

  @spec execute(map(), binary(), map(), function(), GenServer.server(), integer()) :: term()
  def execute(attributes, operator_token, config, clock, store_server, deadline)
      when is_map(attributes) and is_binary(operator_token) and is_map(config) and
             is_function(clock, 0) do
    with :ok <- authorize_operator(operator_token, config),
         {:ok, issued_at} <- trusted_time(clock),
         :ok <- validate_attributes(attributes),
         {:ok, graphs} <- graph_iris(issued_at),
         {:ok, snapshot} <-
           request(store_server, {:semantic_snapshot, Map.values(graphs)}, deadline),
         :ok <- pristine?(snapshot, attributes.expected_dataset_revision),
         {:ok, additions} <- additions(attributes, graphs, issued_at),
         :ok <- validate_graphs(additions, graphs, issued_at, deadline),
         fingerprint = fingerprint(attributes, issued_at),
         {:ok, batch} <-
           WriteBatch.new(additions,
             commit_id: "urn:jido-code:commit:authority_bootstrap_v1",
             expected_dataset_revision: attributes.expected_dataset_revision,
             expected_graph_revisions: Map.new(Map.values(graphs), &{&1, 0}),
             operation_metadata: %{
               class: :authority_bootstrap,
               command_iri: attributes.command_iri,
               request_fingerprint: fingerprint,
               version: "1.0.0"
             }
           ),
         {:ok, receipt} <- request(store_server, {:atomic_update, batch}, deadline) do
      {:ok,
       %{
         outcome: :committed,
         command_iri: attributes.command_iri,
         factory_iri: attributes.factory_iri,
         actor_iri: attributes.actor_iri,
         graph_iris: graphs,
         dataset_revision: receipt.dataset_revision,
         graph_revisions: receipt.graph_revisions,
         issued_at: issued_at
       }}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :authority_bootstrap)}
  catch
    _kind, _reason -> {:error, Error.new(:unavailable, :authority_bootstrap)}
  end

  def execute(_attributes, _token, _config, _clock, _server, _deadline),
    do: {:error, Error.new(:unauthorized, :authority_bootstrap)}

  @spec token_digest(binary()) :: binary()
  def token_digest(token) when is_binary(token), do: :crypto.hash(:sha256, token)

  defp authorize_operator(token, %{enabled?: true, token_digest: expected})
       when is_binary(expected) and byte_size(expected) == 32 do
    if Plug.Crypto.secure_compare(token_digest(token), expected),
      do: :ok,
      else: {:error, Error.new(:unauthorized, :authority_bootstrap)}
  end

  defp authorize_operator(_token, _config),
    do: {:error, Error.new(:unauthorized, :authority_bootstrap)}

  defp trusted_time(clock) do
    case clock.() do
      %DateTime{} = time -> {:ok, DateTime.truncate(time, :microsecond)}
      _invalid -> {:error, Error.new(:invalid_input, :bootstrap_clock)}
    end
  end

  defp validate_attributes(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:command_iri]),
         :ok <- ResourceIdentity.validate(attributes[:factory_iri]),
         :ok <- ResourceIdentity.validate(attributes[:principal_iri]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         :ok <- ResourceIdentity.validate(attributes[:factory_scope_iri]),
         true <- attributes[:principal_iri] == attributes[:actor_iri],
         true <- is_integer(attributes[:expected_dataset_revision]),
         true <- attributes[:expected_dataset_revision] >= 1 do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :authority_bootstrap)}
    end
  end

  defp graph_iris(issued_at) do
    with {:ok, catalog} <- GraphRegistry.graph_iri(:factory_catalog, %{}),
         {:ok, policy} <- GraphRegistry.graph_iri(:factory_policy, %{}),
         {:ok, audit} <- AuditPolicy.graph_iri(issued_at) do
      {:ok, %{catalog: catalog, policy: policy, audit: audit}}
    end
  end

  defp pristine?(snapshot, expected_revision) do
    empty? = Enum.all?(snapshot.graph_metadata, fn {_graph, metadata} -> is_nil(metadata) end)

    if snapshot.dataset_revision == expected_revision and empty?,
      do: :ok,
      else: {:error, Error.new(:conflict, :authority_bootstrap_complete)}
  end

  defp additions(attributes, graphs, issued_at) do
    with {:ok, catalog_metadata} <- metadata(graphs.catalog, attributes, issued_at),
         {:ok, policy_metadata} <- metadata(graphs.policy, attributes, issued_at),
         {:ok, audit_metadata} <- metadata(graphs.audit, attributes, issued_at),
         {:ok, catalog_quads} <- GraphMetadata.quads(catalog_metadata),
         {:ok, policy_quads} <- GraphMetadata.quads(policy_metadata),
         {:ok, audit_quads} <- GraphMetadata.quads(audit_metadata),
         {:ok, grant_quads} <- grant_quads(attributes, graphs.policy, issued_at) do
      catalog =
        catalog_quads ++
          [
            quad(attributes.factory_iri, @rdf_type, iri("RepositoryFactory"), graphs.catalog),
            quad(attributes.actor_iri, @rdf_type, iri("Actor"), graphs.catalog),
            quad(
              attributes.factory_iri,
              @jf <> "bootstrapComplete",
              RDF.XSD.Boolean.new(true),
              graphs.catalog
            ),
            quad(
              attributes.factory_iri,
              @jf <> "bootstrapCommand",
              RDF.iri(attributes.command_iri),
              graphs.catalog
            )
          ]

      audit =
        audit_quads ++
          [
            quad(attributes.command_iri, @rdf_type, RDF.iri(@prov_activity), graphs.audit),
            quad(
              attributes.command_iri,
              @prov_associated,
              RDF.iri(attributes.actor_iri),
              graphs.audit
            ),
            quad(
              attributes.command_iri,
              @prov_generated_at,
              RDF.XSD.DateTime.new(issued_at),
              graphs.audit
            ),
            quad(
              attributes.command_iri,
              @jf <> "outcome",
              RDF.iri("https://jido.run/ontology/outcome/committed"),
              graphs.audit
            ),
            quad(
              attributes.command_iri,
              @jf <> "recordedAt",
              RDF.XSD.DateTime.new(issued_at),
              graphs.audit
            )
          ]

      all = Enum.uniq(catalog ++ policy_quads ++ grant_quads ++ audit)
      :ok = AuditPolicy.validate(audit)
      {:ok, all}
    end
  end

  defp metadata(graph, attributes, issued_at) do
    GraphMetadata.new(graph, %{
      owner_scope: attributes.factory_scope_iri,
      ontology_version: "https://jido.run/ontology/release/1.0.0",
      creation_activity: attributes.command_iri,
      created_at: issued_at,
      lifecycle_state: :open,
      completeness_state: :complete,
      graph_revision: 1
    })
  end

  defp grant_quads(attributes, graph, issued_at) do
    quads =
      Enum.flat_map(Authorization.capabilities(), fn capability ->
        {:ok, grant} =
          ResourceIdentity.deterministic(
            :authorization_grant,
            attributes.actor_iri <> "\n" <> Atom.to_string(capability)
          )

        capability_iri = Authorization.capability_iri(capability)

        [
          quad(grant, @rdf_type, iri("AuthorizationGrant"), graph),
          quad(grant, @jf <> "grantee", RDF.iri(attributes.actor_iri), graph),
          quad(grant, @jf <> "grantsCapability", RDF.iri(capability_iri), graph),
          quad(grant, @jf <> "validFor", RDF.iri(attributes.factory_scope_iri), graph),
          quad(grant, @jf <> "scopeMode", RDF.iri(@all_scopes), graph),
          quad(grant, @jf <> "validFrom", RDF.XSD.DateTime.new(issued_at), graph),
          quad(grant, @jf <> "validTo", RDF.XSD.DateTime.new(@valid_to), graph),
          quad(grant, @jf <> "sourceActivity", RDF.iri(attributes.command_iri), graph)
        ]
      end)

    {:ok, quads}
  end

  defp validate_graphs(additions, graphs, issued_at, deadline) do
    Enum.reduce_while(Map.values(graphs), :ok, fn graph, :ok ->
      {:ok, family} = GraphRegistry.identify(graph)

      {:ok, metadata} =
        metadata(
          graph,
          %{factory_scope_iri: owner(additions, graph), command_iri: activity(additions, graph)},
          issued_at
        )

      graph_additions =
        Enum.filter(additions, fn {_, _, _, stored_graph} ->
          RDF.IRI.to_string(stored_graph) == graph
        end)

      case Validator.validate(
             %{
               operation: :create,
               family: family,
               graph_iri: graph,
               metadata: metadata,
               existing: [],
               additions: graph_additions,
               shape_version: "1.0.0"
             },
             deadline_monotonic_ms: deadline
           ) do
        {:ok, _report} -> {:cont, :ok}
        {:error, %Error{} = error, _report} -> {:halt, {:error, error}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp owner(additions, graph), do: object_iri(additions, graph, @jf <> "ownerScope")
  defp activity(additions, graph), do: object_iri(additions, graph, @jf <> "creationActivity")

  defp object_iri(additions, graph, predicate) do
    Enum.find_value(additions, fn
      {_, %RDF.IRI{value: ^predicate}, %RDF.IRI{value: value}, %RDF.IRI{value: ^graph}} -> value
      _other -> nil
    end)
  end

  defp fingerprint(attributes, issued_at) do
    {attributes.command_iri, attributes.factory_iri, attributes.actor_iri,
     attributes.factory_scope_iri, attributes.expected_dataset_revision, issued_at}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp request(server, operation, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining > 0,
      do: StoreServer.request(server, operation, remaining),
      else: {:error, Error.new(:timeout, :authority_bootstrap)}
  catch
    :exit, {:timeout, _details} -> {:error, Error.new(:timeout, :authority_bootstrap)}
    :exit, _reason -> {:error, Error.new(:unavailable, :authority_bootstrap)}
  end

  defp iri(local), do: RDF.iri(@jf <> local)
  defp quad(subject, predicate, object, graph), do: RDF.quad(subject, predicate, object, graph)
end
