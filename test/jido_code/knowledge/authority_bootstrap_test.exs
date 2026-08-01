defmodule JidoCode.Knowledge.AuthorityBootstrapTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.AuditPolicy
  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Bootstrap
  alias JidoCode.Knowledge.ChangeSet
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_invalidated "http://www.w3.org/ns/prov#invalidatedAtTime"
  @issued ~U[2026-07-31 17:00:00Z]
  @token "local-bootstrap-fixture-token"

  test "resolves exact delegated authority and rejects ambiguity, expiry, and graph widening" do
    fixture = authority_fixture()
    assert {:ok, context} = AuthorityContext.new(fixture.context)
    assert context.principal_iri == fixture.agent

    assert {:ok, envelope} = delegated_envelope(fixture)
    assert {:ok, change_set} = ChangeSet.new(envelope)
    assert {:ok, definition} = CommandRegistry.resolve("ProposeGoal", "1.0.0")
    snapshot = %{dataset: RDF.Dataset.new(fixture.quads)}

    assert {:ok, authority} = Authorization.authorize(envelope, definition, change_set, snapshot)
    assert authority.actor_iri == fixture.actor
    assert authority.delegated_agent_iri == fixture.agent
    assert authority.delegation_iri == fixture.delegation

    assert {:error, _error} =
             Authorization.authorize_at(
               envelope,
               definition,
               change_set,
               snapshot,
               ~U[2028-01-01 00:00:00Z]
             )

    duplicate = resource!("duplicate-delegation")

    ambiguous =
      fixture.quads ++
        Enum.map(fixture.delegation_quads, fn {subject, predicate, object, graph} ->
          replacement =
            if RDF.IRI.to_string(subject) == fixture.delegation, do: duplicate, else: subject

          RDF.quad(replacement, predicate, object, graph)
        end)

    assert {:error, _error} =
             Authorization.authorize(
               envelope,
               definition,
               change_set,
               %{dataset: RDF.Dataset.new(ambiguous)}
             )

    expired =
      replace_object(
        fixture.quads,
        fixture.delegation,
        @jf <> "validTo",
        ~U[2026-01-01 00:00:00Z]
      )

    assert {:error, _error} =
             Authorization.authorize(
               envelope,
               definition,
               change_set,
               %{dataset: RDF.Dataset.new(expired)}
             )

    wrong_graph =
      replace_object(
        fixture.quads,
        fixture.delegation,
        @jf <> "graphBoundary",
        "https://jido.run/graph/factory/catalog"
      )

    assert {:error, _error} =
             Authorization.authorize(
               envelope,
               definition,
               change_set,
               %{dataset: RDF.Dataset.new(wrong_graph)}
             )

    revoked =
      fixture.quads ++
        [
          RDF.quad(
            fixture.delegation,
            @prov_invalidated,
            RDF.XSD.DateTime.new(@issued),
            fixture.policy_graph
          )
        ]

    assert {:error, _error} =
             Authorization.authorize(
               envelope,
               definition,
               change_set,
               %{dataset: RDF.Dataset.new(revoked)}
             )
  end

  test "bootstraps authority once and enables governed commands", context do
    root = unique_root(context)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    substrate = start_substrate!(config)

    on_exit(fn ->
      stop_process(substrate.writer)
      stop_process(substrate.server)
      File.rm_rf!(root)
    end)

    assert {:ok, ontology} =
             Release.load(store_server: substrate.server, writer: substrate.writer)

    assert ontology.receipt.dataset_revision == 1

    attrs = bootstrap_attributes()

    assert {:ok, receipt} =
             Writer.bootstrap(substrate.writer, attrs, operator_token: @token)

    assert receipt.outcome == :committed
    assert receipt.dataset_revision == 2
    assert map_size(receipt.graph_iris) == 3

    assert {:ok, counts} =
             StoreServer.request(
               substrate.server,
               {:graph_counts, Map.values(receipt.graph_iris)}
             )

    assert Enum.all?(counts, fn {_graph, count} -> count > 0 end)

    assert {:error, %{kind: :conflict, operation: :authority_bootstrap_complete}} =
             Writer.bootstrap(substrate.writer, attrs, operator_token: @token)

    assert {:error, %{kind: :unauthorized}} =
             Writer.bootstrap(substrate.writer, attrs, operator_token: "wrong-token")

    command = enrollment_envelope!(attrs, receipt.graph_iris.catalog)
    assert {:ok, command_receipt} = Writer.execute(substrate.writer, command)
    assert command_receipt.outcome == :committed
    assert command_receipt.dataset_revision == 3
  end

  test "rejects forbidden audit payloads and separates audit-read capability" do
    graph = "https://jido.run/graph/security/audit/2026-07"
    subject = resource!("audit-subject")

    assert {:error, %{operation: :audit_payload}} =
             AuditPolicy.validate([
               RDF.quad(subject, @jf <> "prompt", "secret fixture body", graph)
             ])

    refute AuditPolicy.read_allowed?(:control)
    assert AuditPolicy.read_allowed?(:security)
    assert AuditPolicy.read_allowed?(:administrative)
  end

  defp authority_fixture do
    actor = resource!("delegating-actor")
    agent = resource!("delegated-agent")
    grant = resource!("proposal-grant")
    delegation = local!(:delegation, 1)
    repository = resource!("delegated-repository")
    scope = scope!(:repository, "delegated-repository")
    {:ok, policy_graph} = GraphRegistry.graph_iri(:factory_policy, %{})
    {:ok, control_graph} = GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    grant_quads = [
      quad(grant, @rdf_type, iri("AuthorizationGrant"), policy_graph),
      quad(grant, @jf <> "grantee", RDF.iri(actor), policy_graph),
      quad(
        grant,
        @jf <> "grantsCapability",
        RDF.iri(Authorization.capability_iri(:proposal)),
        policy_graph
      ),
      quad(grant, @jf <> "validFor", RDF.iri(scope), policy_graph),
      quad(
        grant,
        @jf <> "validFrom",
        RDF.XSD.DateTime.new(~U[2026-01-01 00:00:00Z]),
        policy_graph
      ),
      quad(grant, @jf <> "validTo", RDF.XSD.DateTime.new(~U[2027-01-01 00:00:00Z]), policy_graph)
    ]

    delegation_quads = [
      quad(delegation, @rdf_type, iri("Delegation"), policy_graph),
      quad(delegation, @jf <> "delegatingActor", RDF.iri(actor), policy_graph),
      quad(delegation, @jf <> "delegatedAgent", RDF.iri(agent), policy_graph),
      quad(
        delegation,
        @jf <> "grantsCapability",
        RDF.iri(Authorization.capability_iri(:proposal)),
        policy_graph
      ),
      quad(delegation, @jf <> "validFor", RDF.iri(scope), policy_graph),
      quad(
        delegation,
        @jf <> "commandClass",
        RDF.iri(Authorization.command_class_iri("ProposeGoal")),
        policy_graph
      ),
      quad(delegation, @jf <> "graphBoundary", RDF.iri(control_graph), policy_graph),
      quad(
        delegation,
        @jf <> "validFrom",
        RDF.XSD.DateTime.new(~U[2026-01-01 00:00:00Z]),
        policy_graph
      ),
      quad(
        delegation,
        @jf <> "validTo",
        RDF.XSD.DateTime.new(~U[2027-01-01 00:00:00Z]),
        policy_graph
      )
    ]

    %{
      actor: actor,
      agent: agent,
      grant: grant,
      delegation: delegation,
      repository: repository,
      scope: scope,
      policy_graph: policy_graph,
      control_graph: control_graph,
      grant_quads: grant_quads,
      delegation_quads: delegation_quads,
      quads: grant_quads ++ delegation_quads,
      context: %{
        principal_iri: agent,
        actor_iri: actor,
        delegated_agent_iri: agent,
        delegation_iri: delegation
      }
    }
  end

  defp delegated_envelope(fixture) do
    goal = local!(:goal, 2)

    CommandEnvelope.new(
      %{
        command_type: "ProposeGoal",
        command_version: "1.0.0",
        command_iri: local!(:command, 3),
        principal_iri: fixture.agent,
        actor_iri: fixture.actor,
        delegated_agent_iri: fixture.agent,
        delegation_iri: fixture.delegation,
        scope_iri: fixture.scope,
        idempotency_key: "delegated-request",
        correlation_iri: local!(:activity, 4),
        causation_iri: local!(:command, 5),
        ontology_version: "1.0.0",
        shape_version: "1.0.0",
        expected_dataset_revision: 2,
        expected_graph_revisions: %{fixture.control_graph => 1},
        reason: "delegated proposal",
        payload: %{
          changes: [
            %{
              family: :repository_control,
              graph_iri: fixture.control_graph,
              operation: :append,
              metadata: %{lifecycle_state: :open},
              additions: [{goal, @rdf_type, iri("Goal")}],
              supersessions: [],
              invalidations: [],
              removals: []
            }
          ]
        }
      },
      clock: fn -> @issued end
    )
  end

  defp bootstrap_attributes do
    %{
      command_iri: local!(:command, 10),
      factory_iri: resource!("bootstrap-factory"),
      principal_iri: resource!("bootstrap-actor"),
      actor_iri: resource!("bootstrap-actor"),
      factory_scope_iri: scope!(:factory, "default"),
      expected_dataset_revision: 1
    }
  end

  defp enrollment_envelope!(attrs, catalog_graph) do
    repository = resource!("bootstrap-enrolled-repository")

    {:ok, envelope} =
      CommandEnvelope.new(
        %{
          command_type: "EnrollRepository",
          command_version: "1.0.0",
          command_iri: local!(:command, 11),
          principal_iri: attrs.actor_iri,
          actor_iri: attrs.actor_iri,
          delegated_agent_iri: nil,
          delegation_iri: nil,
          scope_iri: scope!(:repository, "bootstrap-enrolled-repository"),
          idempotency_key: "bootstrap-enrollment",
          correlation_iri: local!(:activity, 12),
          causation_iri: attrs.command_iri,
          ontology_version: "1.0.0",
          shape_version: "1.0.0",
          expected_dataset_revision: 2,
          expected_graph_revisions: %{catalog_graph => 1},
          reason: "initial managed repository",
          payload: %{
            changes: [
              %{
                family: :factory_catalog,
                graph_iri: catalog_graph,
                operation: :append,
                metadata: %{lifecycle_state: :open},
                additions: [{repository, @rdf_type, iri("SoftwareRepository")}],
                supersessions: [],
                invalidations: [],
                removals: []
              }
            ]
          }
        },
        clock: fn -> @issued end
      )

    envelope
  end

  defp replace_object(quads, subject, predicate, replacement) do
    Enum.map(quads, fn
      {%RDF.IRI{value: ^subject}, %RDF.IRI{value: ^predicate}, _object, graph} ->
        RDF.quad(subject, predicate, replacement_term(replacement), graph)

      quad ->
        quad
    end)
  end

  defp replacement_term(%DateTime{} = time), do: RDF.XSD.DateTime.new(time)
  defp replacement_term(value), do: RDF.iri(value)

  defp start_substrate!(config) do
    readiness = start_child!({Readiness, name: nil})
    writer_name = {:global, {__MODULE__, :writer, make_ref()}}

    server =
      start_child!(
        {StoreServer,
         name: nil,
         readiness: readiness,
         config: config,
         authorized_callers: %{
           read: [self()],
           write: [writer_name],
           maintenance: [self()]
         }}
      )

    assert await_health(server, :ready).ready?

    writer =
      start_child!(
        {Writer,
         name: writer_name,
         store_server: server,
         bootstrap_config: %{enabled?: true, token_digest: Bootstrap.token_digest(@token)},
         clock: fn -> @issued end}
      )

    %{server: server, writer: writer}
  end

  defp start_child!(child) do
    child
    |> Supervisor.child_spec(id: make_ref(), restart: :temporary)
    |> start_supervised!()
  end

  defp await_health(server, expected, attempts \\ 500)
  defp await_health(server, _expected, 0), do: StoreServer.summary(server)

  defp await_health(server, expected, attempts) do
    summary = StoreServer.summary(server)

    if summary.health_state == expected do
      summary
    else
      Process.sleep(10)
      await_health(server, expected, attempts - 1)
    end
  end

  defp stop_process(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
  catch
    :exit, _reason -> :ok
  end

  defp resource!(value) do
    {:ok, iri} = ResourceIdentity.repository(value)
    iri
  end

  defp scope!(kind, value) do
    {:ok, iri} = ResourceIdentity.scope(kind, value)
    iri
  end

  defp local!(kind, timestamp) do
    entropy = :binary.copy(<<rem(timestamp, 255)>>, 10)
    {:ok, iri} = ResourceIdentity.local(kind, timestamp, entropy)
    iri
  end

  defp iri(local), do: RDF.iri(@jf <> local)
  defp quad(subject, predicate, object, graph), do: RDF.quad(subject, predicate, object, graph)

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-authority-bootstrap-#{name}-#{unique}")
  end
end
