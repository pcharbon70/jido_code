defmodule JidoCode.Knowledge.CommandContractTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.ChangeSet
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @time ~U[2026-07-31 16:45:00Z]

  test "registers only fixed intent-named command versions" do
    assert length(CommandRegistry.names()) == 12
    assert {:ok, definition} = CommandRegistry.resolve("ProposeGoal", "1.0.0")
    assert definition.capability == :proposal
    assert definition.graph_families == [:repository_control]
    assert CommandRegistry.generic_crud?("CreateEntity")

    assert {:error, %Error{operation: :command_type}} =
             CommandRegistry.resolve("CreateEntity", "1.0.0")

    assert {:ok, %{version: "2.0.0"}} =
             CommandRegistry.resolve("ProposeGoal", "2.0.0")

    assert {:error, %Error{kind: :incompatible}} =
             CommandRegistry.resolve("ProposeGoal", "2.1.0")
  end

  test "builds a clocked envelope while redacting payload and idempotency material" do
    attributes = command_attributes()
    assert {:ok, envelope} = CommandEnvelope.new(attributes, clock: fn -> @time end)
    assert envelope.issued_at == @time
    assert envelope.payload == attributes.payload

    inspected = inspect(envelope)
    refute inspected =~ attributes.idempotency_key
    refute inspected =~ attributes.reason
    refute inspected =~ "sensitive-fixture-body"

    safe = CommandEnvelope.safe_map(envelope)
    assert safe.idempotency_key == :redacted
    assert safe.payload == :redacted

    assert {:error, %Error{operation: :command_envelope}} =
             CommandEnvelope.new(Map.put(attributes, :issued_at, @time), clock: fn -> @time end)
  end

  test "canonicalizes equivalent graph deltas and rejects ordinary removals" do
    attributes = command_attributes()
    assert {:ok, first_envelope} = CommandEnvelope.new(attributes, clock: fn -> @time end)

    reversed =
      update_in(attributes, [:payload, :changes], fn [change] ->
        [%{change | additions: Enum.reverse(change.additions)}]
      end)

    assert {:ok, second_envelope} = CommandEnvelope.new(reversed, clock: fn -> @time end)
    assert {:ok, first} = ChangeSet.new(first_envelope)
    assert {:ok, second} = ChangeSet.new(second_envelope)
    assert first.request_fingerprint == second.request_fingerprint
    assert first.change_set_iri == second.change_set_iri
    assert first.assertion_count == 2
    assert first.supersession_count == 1

    with_removal =
      update_in(attributes, [:payload, :changes], fn [change] ->
        [%{change | removals: change.additions}]
      end)

    assert {:ok, removal_envelope} = CommandEnvelope.new(with_removal, clock: fn -> @time end)
    assert {:error, %Error{operation: :change_removal}} = ChangeSet.new(removal_envelope)
  end

  test "bounds failure disclosure and conceals unauthorized lookups" do
    unauthorized =
      CommandReceipt.failure(:unauthorized,
        command_iri: local!(:command, 1),
        current_revisions: %{secret: 4},
        issues: ["policy_detail"]
      )

    assert unauthorized == %CommandReceipt{outcome: :unauthorized, retry: :never}

    invalid =
      CommandReceipt.failure(:invalid,
        issues: ["shape_violation", "unsafe issue detail", String.duplicate("x", 81)]
      )

    assert invalid.issues == ["shape_violation"]
  end

  defp command_attributes do
    repository = repository!("command-contract-repository")
    actor = repository!("command-contract-actor")
    principal = repository!("command-contract-principal")
    scope = scope!(:repository, "command-contract-repository")
    command = local!(:command, 1)
    correlation = local!(:activity, 2)
    cause = local!(:command, 3)
    goal = local!(:goal, 4)
    old_goal = local!(:goal, 5)
    {:ok, graph} = GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    %{
      command_type: "ProposeGoal",
      command_version: "1.0.0",
      command_iri: command,
      principal_iri: principal,
      actor_iri: actor,
      delegated_agent_iri: nil,
      delegation_iri: nil,
      scope_iri: scope,
      idempotency_key: "external-delivery-42",
      correlation_iri: correlation,
      causation_iri: cause,
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: 4,
      expected_graph_revisions: %{graph => 2},
      reason: "governed proposal",
      payload: %{
        fixture_note: "sensitive-fixture-body",
        changes: [
          %{
            family: :repository_control,
            graph_iri: graph,
            operation: :append,
            metadata: %{lifecycle_state: :open},
            additions: [
              {goal, @rdf_type, RDF.iri(@jf <> "Goal")},
              {goal, @jf <> "about", RDF.iri(repository)}
            ],
            supersessions: [{goal, old_goal}],
            invalidations: [],
            removals: []
          }
        ]
      }
    }
  end

  defp repository!(value) do
    {:ok, iri} = ResourceIdentity.repository(value)
    iri
  end

  defp scope!(kind, value) do
    {:ok, iri} = ResourceIdentity.scope(kind, value)
    iri
  end

  defp local!(kind, timestamp) do
    {:ok, iri} = ResourceIdentity.local(kind, timestamp, :binary.copy(<<timestamp>>, 10))
    iri
  end
end
