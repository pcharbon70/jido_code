defmodule JidoCode.Knowledge.Memory.Phase06ContentAccessTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.ContentAccessCommand
  alias JidoCode.Knowledge.Memory.ContentAccessOutcome
  alias JidoCode.Knowledge.Memory.ContentCipher
  alias JidoCode.Knowledge.Memory.InMemoryContentKeyProvider
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @now ~U[2026-08-21 18:00:00Z]
  @later ~U[2026-08-21 18:01:00Z]

  setup do
    {:ok, keys} =
      start_supervised(
        {InMemoryContentKeyProvider, random_bytes: fn count -> :binary.copy(<<count>>, count) end}
      )

    {:ok, ledger} = start_supervised({Agent, fn -> MapSet.new() end})
    %{keys: keys, ledger: ledger}
  end

  test "encrypts with per-object keys and supports rotation, revocation, and cryptographic erasure",
       %{keys: keys} do
    tenant = resource(:authorization_grant, "content-tenant")
    object = resource(:episode_content, "content-object")
    attributes = cipher_attributes()

    assert {:ok, encrypted} =
             Knowledge.encrypt_content(
               InMemoryContentKeyProvider,
               keys,
               tenant,
               object,
               "0123456789secret",
               attributes,
               random_bytes: fn 12 -> String.duplicate(<<7>>, 12) end
             )

    refute Enum.join(encrypted.ciphertext_chunks) == "0123456789secret"
    assert encrypted.key_generation == 1

    assert {:ok, "0123456789secret"} =
             ContentCipher.decrypt(InMemoryContentKeyProvider, keys, encrypted, attributes)

    assert {:ok, rotated} =
             Knowledge.encrypt_content(
               InMemoryContentKeyProvider,
               keys,
               tenant,
               object,
               "rotated payload",
               attributes,
               key_operation: :rotate,
               random_bytes: fn 12 -> String.duplicate(<<8>>, 12) end
             )

    assert rotated.key_generation == 2
    refute rotated.key_reference_iri == encrypted.key_reference_iri

    assert :ok = InMemoryContentKeyProvider.revoke_key(keys, rotated.key_reference_iri)

    assert {:error, %Error{kind: :unauthorized}} =
             ContentCipher.decrypt(InMemoryContentKeyProvider, keys, rotated, attributes)

    assert :ok = InMemoryContentKeyProvider.destroy_key(keys, encrypted.key_reference_iri)

    assert {:error, %Error{kind: :unavailable}} =
             ContentCipher.decrypt(InMemoryContentKeyProvider, keys, encrypted, attributes)

    assert {:error, %Error{kind: :unauthorized}} =
             Knowledge.encrypt_content(
               InMemoryContentKeyProvider,
               keys,
               tenant,
               resource(:episode_content, "secret-object"),
               "secret value",
               %{attributes | classification: :secret_value}
             )
  end

  test "binds every permit dimension and requires exact agent execution context" do
    assert {:ok, permit} = Knowledge.content_access_permit(permit_attributes())
    assert permit.state == :authorized
    assert permit.parameters_digest == digest_term(%{content: "selected"})

    assert :ok = JidoCode.Knowledge.Memory.ContentAccessPermit.recheck(permit, context(permit))

    for changed <- [
          %{context(permit) | authorization_revision: 8},
          %{context(permit) | lifecycle_state: :erase_requested},
          %{context(permit) | sink: :approved_export},
          %{context(permit) | destination: "wrong"},
          %{context(permit) | byte_range: %{offset: 0, length: 1}},
          %{context(permit) | agent_context: %{permit.agent_context | fence: 10}},
          %{context(permit) | now: permit.expires_at},
          %{context(permit) | permit_consumed?: true}
        ] do
      assert {:error, %Error{kind: :unauthorized}} =
               JidoCode.Knowledge.Memory.ContentAccessPermit.recheck(permit, changed)
    end

    assert {:error, %Error{kind: :invalid_input}} =
             permit_attributes()
             |> Map.put(:agent_context, nil)
             |> Knowledge.content_access_permit()
  end

  test "consumes once before exact release and records only bounded audit metadata", %{
    keys: keys,
    ledger: ledger
  } do
    permit_attributes = permit_attributes()
    object = permit_attributes.content_iri
    tenant = resource(:authorization_grant, "content-tenant")
    attributes = cipher_attributes()

    assert {:ok, encrypted} =
             Knowledge.encrypt_content(
               InMemoryContentKeyProvider,
               keys,
               tenant,
               object,
               "0123456789secret",
               attributes,
               random_bytes: fn 12 -> String.duplicate(<<9>>, 12) end
             )

    assert {:ok, permit} = Knowledge.content_access_permit(permit_attributes)
    consume = consume_once(ledger)

    options = [
      consume_permit: consume,
      key_provider: InMemoryContentKeyProvider,
      key_server: keys,
      cipher_attributes: attributes,
      release: fn bytes -> {:ok, %{released: byte_size(bytes)}} end
    ]

    assert {:ok, "234567", %ContentAccessOutcome{} = outcome} =
             Knowledge.release_content(permit, encrypted, context(permit), options)

    assert outcome.status == :released
    assert outcome.byte_count == 6
    audit = inspect(ContentAccessOutcome.statements(outcome))
    refute String.contains?(audit, "234567")
    refute Map.has_key?(Map.from_struct(outcome), :bytes)

    assert {:error, %Error{kind: :conflict}, replay} =
             Knowledge.release_content(permit, encrypted, context(permit), options)

    assert replay.status == :denied
    assert replay.byte_count == 0
  end

  test "a crash after consumption is attributable and cannot replay", %{
    keys: keys,
    ledger: ledger
  } do
    attributes = cipher_attributes()
    permit_attributes = %{permit_attributes() | destination: "agent-context/crash"}
    assert {:ok, permit} = Knowledge.content_access_permit(permit_attributes)

    assert {:ok, encrypted} =
             Knowledge.encrypt_content(
               InMemoryContentKeyProvider,
               keys,
               resource(:authorization_grant, "crash-tenant"),
               permit.content_iri,
               "0123456789secret",
               attributes,
               random_bytes: fn 12 -> String.duplicate(<<10>>, 12) end
             )

    options = [
      consume_permit: consume_once(ledger),
      key_provider: InMemoryContentKeyProvider,
      key_server: keys,
      cipher_attributes: attributes,
      crash_after_consumption: true
    ]

    assert {:error, %Error{kind: :persistence_failure}, outcome} =
             Knowledge.release_content(permit, encrypted, context(permit), options)

    assert outcome.status == :ambiguous
    assert outcome.byte_count == 0

    assert {:error, %Error{kind: :conflict}, replay} =
             Knowledge.release_content(permit, encrypted, context(permit), options)

    assert replay.status == :denied
  end

  test "publishes distinct authorization, consumption, and outcome commands" do
    repository = resource(:repository_snapshot, "content-access-repository")
    assert {:ok, permit} = Knowledge.content_access_permit(permit_attributes())
    attributes0 = command_attributes(repository, 0)

    assert {:ok, authorize} =
             Knowledge.authorize_content_access(
               permit,
               repository,
               0,
               attributes0,
               clock: fn -> @now end
             )

    assert authorize.command_type == "AuthorizeContentAccess"

    assert {:ok, consume} =
             Knowledge.consume_content_access(
               permit,
               repository,
               1,
               command_attributes(repository, 1),
               clock: fn -> @later end
             )

    assert consume.command_type == "ConsumeContentAccess"
    assert {:ok, activity_iri} = ContentAccessCommand.consumption_iri(permit.iri)
    assert consume.payload.content_access_iri == activity_iri

    assert {:ok, outcome} =
             ContentAccessOutcome.new(%{
               permit_iri: permit.iri,
               content_iri: permit.content_iri,
               selected_iris: [permit.content_iri],
               status: :failed,
               byte_count: 0,
               ciphertext_commitment: digest("ciphertext and range"),
               reason: "release failed after consumption",
               recorded_at: @later
             })

    assert {:ok, record} =
             Knowledge.record_content_access_outcome(
               permit,
               outcome,
               repository,
               2,
               command_attributes(repository, 2),
               clock: fn -> @later end
             )

    assert record.command_type == "RecordContentAccessOutcome"

    for command <- [authorize, consume, record] do
      assert command.command_version == CommandRegistry.content_version()

      assert {:ok, definition} =
               CommandRegistry.resolve(command.command_type, command.command_version)

      assert definition.capability == :content_lifecycle_writer
    end
  end

  defp cipher_attributes do
    %{
      classification: :encrypted_content,
      media_type: "application/octet-stream",
      policy_revision: DataPolicy.revision(),
      provider_private_state?: false,
      hidden_reasoning?: false
    }
  end

  defp permit_attributes do
    %{
      actor_iri: resource(:authorization_grant, "content-reader"),
      purpose: :managed_continuity,
      task_iri: resource(:task_proposal, "content-task"),
      scope_iri: resource(:execution_context, "content-scope"),
      authorization_iri: resource(:authorization_grant, "content-authorization"),
      authorization_revision: 7,
      reviewed_query: :episode_content_selection,
      query_version: "1.0.0",
      parameters: %{content: "selected"},
      content_iri: resource(:episode_content, "content-object"),
      content_version: "1.0.0",
      representation: :exact_binary,
      byte_range: %{offset: 2, length: 6},
      sink: :agent_context,
      destination: "agent-context/invocation-1",
      method: :read,
      issued_at: @now,
      expires_at: DateTime.add(@now, 120, :second),
      data_ceiling: :encrypted_content,
      agent_context: %{
        attempt_iri: resource(:execution_attempt, "content-attempt"),
        lease_iri: resource(:execution_lease, "content-lease"),
        fence: 9,
        context_iri: resource(:execution_context, "content-context"),
        invocation_iri: resource(:model_invocation, "content-invocation"),
        model_access_profile_iri: resource(:model_access_profile, "content-model-profile")
      }
    }
  end

  defp context(permit) do
    %{
      permit_consumed?: false,
      authorization_decision: :allowed,
      authorization_iri: permit.authorization_iri,
      authorization_revision: permit.authorization_revision,
      authorization_revoked?: false,
      actor_iri: permit.actor_iri,
      scope_iri: permit.scope_iri,
      purpose: permit.purpose,
      content_iri: permit.content_iri,
      content_version: permit.content_version,
      representation: permit.representation,
      byte_range: permit.byte_range,
      sink: permit.sink,
      destination: permit.destination,
      method: permit.method,
      data_ceiling: permit.data_ceiling,
      lifecycle_state: :active,
      hold_access_allowed?: true,
      maximum_release_bytes: 64,
      agent_context: permit.agent_context,
      now: @later
    }
  end

  defp consume_once(ledger) do
    fn permit ->
      Agent.get_and_update(ledger, fn consumed ->
        if MapSet.member?(consumed, permit.iri) do
          {{:error, Error.new(:conflict, :content_permit_consumed)}, consumed}
        else
          {:ok, MapSet.put(consumed, permit.iri)}
        end
      end)
    end
  end

  defp command_attributes(repository, revision) do
    {:ok, graph} = GraphRegistry.graph_iri(:content_lifecycle, %{repository: repository})

    %{
      repository_scope_iri: resource(:execution_context, "content-lifecycle-scope"),
      principal_iri: resource(:authorization_grant, "content-lifecycle-principal"),
      actor_iri: resource(:authorization_grant, "content-lifecycle-actor"),
      delegated_agent_iri: nil,
      delegation_iri: nil,
      correlation_iri: resource(:command_request, "content-lifecycle-correlation-#{revision}"),
      causation_iri: resource(:authorization_grant, "content-lifecycle-cause"),
      expected_dataset_revision: revision + 1,
      expected_graph_revisions: %{graph => revision},
      recorded_at: if(revision == 0, do: @now, else: @later),
      reason: "record exact content access boundary"
    }
  end

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp digest_term(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> digest()
  end
end
