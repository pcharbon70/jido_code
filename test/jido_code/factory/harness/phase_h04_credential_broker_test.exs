defmodule JidoCode.Factory.Harness.PhaseH04CredentialBrokerTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Credential.Policy
  alias JidoCode.Factory.Credential.ReleaseRequest
  alias JidoCode.Factory.CredentialBroker
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeCredentialVault
  alias JidoCode.TestSupport.FakeTrustedConnector

  @connector_digest "sha256:" <> String.duplicate("b", 64)
  @connector_name "JidoCode.TestSupport.FakeTrustedConnector"
  @secret "ghp_1234567890abcdefghijklmnopqrstuv"

  test "policy records exact authority and only proven enforcement claims" do
    assert {:ok, policy} = Policy.new(policy_attributes())
    assert policy.enforcement == :attaching_proxy
    assert policy.scopes == ["contents:write", "pull_requests:write"]
    refute inspect(policy) =~ policy.reference.key
    refute inspect(policy) =~ @secret

    for mutation <- [
          %{policy_attributes() | enforcement: :existing_cli_session},
          %{policy_attributes() | trusted_connector_identity: "unreviewed"},
          %{policy_attributes() | scopes: []},
          %{policy_attributes() | managed_eligible: false, explicit_local_consent: true}
        ] do
      assert {:error, %AdapterError{operation: :credential_policy}} = Policy.new(mutation)
    end
  end

  test "release sends material directly from vault to connector and returns a safe permit" do
    {broker, request, current} = broker_fixture()

    assert {:ok, release} =
             CredentialBroker.release(
               broker,
               request,
               current,
               connector(),
               %{operation: "repository.write", candidate_digest: String.duplicate("c", 64)}
             )

    assert release.permit.single_use
    assert release.permit.scopes == ["contents:write"]
    assert release.enforced_restrictions.enforcement == :attaching_proxy
    assert release.connector_result.status == :completed
    assert_received {:credential_vault_checkout, reference_iri, release_id}
    assert reference_iri == request.policy.reference.iri
    assert release_id == release.permit.id
    assert_received {:trusted_connector_material, ^release_id, byte_count, "repository.write"}
    assert byte_count == byte_size(@secret)
    refute inspect(release) =~ @secret
    refute inspect(release) =~ request.policy.reference.key
  end

  test "every live owner, delegation, revision, invocation, lease, and fence fact is exact" do
    {_broker, request, current} = broker_fixture()

    mutations = [
      &Map.put(&1, :lease_state, :revoked),
      &Map.put(&1, :actor_iri, resource!("other-actor")),
      &Map.put(&1, :delegated_agent_iri, resource!("other-agent")),
      &Map.put(&1, :delegation_iri, resource!("other-delegation")),
      &Map.put(&1, :repository_iri, resource!("other-repository")),
      &Map.put(&1, :provider, "gitlab"),
      &Map.put(&1, :attempt_iri, resource!(:execution_attempt, "other-attempt")),
      &Map.put(&1, :lease_iri, resource!(:execution_lease, "other-lease")),
      &Map.update!(&1, :fencing_token, fn value -> value + 1 end),
      &Map.update!(&1, :profile_revision, fn value -> value + 1 end),
      &Map.update!(&1, :credential_revision, fn value -> value + 1 end),
      &Map.update!(&1, :revocation_generation, fn value -> value + 1 end),
      &Map.put(&1, :invocation_iri, resource!(:tool_invocation, "other-invocation"))
    ]

    for mutate <- mutations do
      broker = start_broker()

      assert {:error, %AdapterError{operation: :credential_authority}} =
               CredentialBroker.release(
                 broker,
                 request,
                 mutate.(current),
                 connector(),
                 %{operation: "repository.write"}
               )

      refute_received {:credential_vault_checkout, _reference, _permit}
      refute_received {:trusted_connector_material, _permit, _bytes, _operation}
    end
  end

  test "operation, audience, minimum scope, managed mode, and connector identity fail closed" do
    assert {:ok, policy} = Policy.new(policy_attributes())

    for attributes <- [
          request_attributes() |> Map.put(:operation, "repository.delete"),
          request_attributes() |> Map.put(:audience, "https://uploads.github.com"),
          request_attributes() |> Map.put(:minimum_scopes, ["administration:write"]),
          request_attributes() |> Map.put(:invocation_iri, resource!(:tool_invocation, "wrong"))
        ] do
      assert {:error, %AdapterError{operation: :credential_release_request}} =
               ReleaseRequest.new(policy, attributes)
    end

    {broker, request, current} = broker_fixture()
    {module, connector} = connector()
    mismatched = put_in(connector, [:identity, :digest], "sha256:" <> String.duplicate("d", 64))

    assert {:error, %AdapterError{operation: :trusted_connector_identity}} =
             CredentialBroker.release(
               broker,
               request,
               current,
               {module, mismatched},
               %{operation: "repository.write"}
             )

    refute_received {:credential_vault_checkout, _reference, _permit}
  end

  test "single-use permits stay consumed after release and expired policy never releases" do
    {broker, request, current} = broker_fixture()
    payload = %{operation: "repository.write"}

    assert {:ok, first} = CredentialBroker.release(broker, request, current, connector(), payload)

    assert {:error, %AdapterError{operation: :credential_permit_reuse}} =
             CredentialBroker.release(broker, request, current, connector(), payload)

    assert_received {:credential_vault_checkout, _reference, first_id}
    assert first_id == first.permit.id
    refute_received {:credential_vault_checkout, _reference, _duplicate}

    future = DateTime.add(request.policy.expires_at, 1, :second)
    expired = start_broker(clock: fn -> future end)

    assert {:error, %AdapterError{operation: :credential_authority}} =
             CredentialBroker.release(expired, request, current, connector(), payload)
  end

  test "developer-local CLI passes only an opaque consented reference and is never managed" do
    local_attributes =
      policy_attributes()
      |> Map.merge(%{
        credential_class: :local_cli_reference,
        enforcement: :existing_cli_session,
        explicit_local_consent: true,
        managed_eligible: false,
        single_use: false
      })

    assert {:ok, policy} = Policy.new(local_attributes)

    assert {:error, %AdapterError{operation: :credential_release_request}} =
             ReleaseRequest.new(policy, %{request_attributes() | managed_claim: true})

    assert {:ok, request} = ReleaseRequest.new(policy, request_attributes())
    broker = start_broker()

    assert {:ok, release} =
             CredentialBroker.release(
               broker,
               request,
               current(policy),
               connector(),
               %{operation: "repository.write"}
             )

    assert release.credential_class == :local_cli_reference
    assert_received {:trusted_connector_reference, permit_id, reference_iri, "repository.write"}
    assert permit_id == release.permit.id
    assert reference_iri == policy.reference.iri
    refute_received {:credential_vault_checkout, _reference, _permit}
    refute inspect(release) =~ policy.reference.key
  end

  test "managed delegated CLI checkout and refresh ownership are serialized by the broker" do
    {:ok, tracker} = Agent.start_link(fn -> %{active: 0, maximum: 0} end)

    delegated =
      policy_attributes()
      |> Map.merge(%{
        credential_class: :delegated_cli,
        enforcement: :broker_helper,
        explicit_local_consent: false,
        managed_eligible: true,
        single_use: false
      })

    assert {:ok, policy} = Policy.new(delegated)

    assert {:ok, request} =
             ReleaseRequest.new(policy, %{request_attributes() | managed_claim: true})

    broker = start_broker(tracker: tracker, delay_ms: 30)
    current = current(policy)

    tasks =
      for _index <- 1..2 do
        Task.async(fn ->
          CredentialBroker.release(
            broker,
            request,
            current,
            connector(),
            %{operation: "repository.write"}
          )
        end)
      end

    assert Enum.all?(Task.await_many(tasks, 1_000), &match?({:ok, _release}, &1))
    assert Agent.get(tracker, & &1.maximum) == 1
  end

  defp broker_fixture do
    assert {:ok, policy} = Policy.new(policy_attributes())
    assert {:ok, request} = ReleaseRequest.new(policy, request_attributes())
    {start_broker(), request, current(policy)}
  end

  defp start_broker(options \\ []) do
    clock = Keyword.get(options, :clock, fn -> DateTime.utc_now() end)

    vault = %{
      owner: self(),
      material: @secret,
      tracker: Keyword.get(options, :tracker),
      delay_ms: Keyword.get(options, :delay_ms)
    }

    start_supervised!(
      {CredentialBroker,
       [
         vault: {FakeCredentialVault, vault},
         clock: clock
       ]},
      id: {:credential_broker, System.unique_integer([:positive, :monotonic])}
    )
  end

  defp connector do
    {FakeTrustedConnector,
     %{
       owner: self(),
       identity: %{
         name: @connector_name,
         digest: @connector_digest,
         trusted: true,
         delivery: :direct,
         credential_classes: [
           :provider_token,
           :oauth_access,
           :delegated_cli,
           :local_cli_reference
         ]
       }
     }}
  end

  defp policy_attributes do
    {:ok, reference} =
      CredentialReference.new(%{
        iri: resource!("credential-reference"),
        provider: "github",
        key: "vault/github/repository-writer"
      })

    %{
      reference: reference,
      credential_class: :provider_token,
      actor_iri: resource!("actor"),
      delegated_agent_iri: resource!("agent"),
      delegation_iri: resource!("delegation"),
      repository_iri: resource!("repository"),
      provider: "github",
      operation: "repository.write",
      audience: "https://api.github.com",
      scopes: ["contents:write", "pull_requests:write"],
      expires_at: DateTime.add(DateTime.utc_now(), 600, :second),
      single_use: true,
      attempt_iri: resource!(:execution_attempt, "attempt"),
      lease_iri: resource!(:execution_lease, "lease"),
      fencing_token: 401,
      trusted_connector_identity: @connector_name <> "@" <> @connector_digest,
      enforcement: :attaching_proxy,
      profile_revision: 7,
      credential_revision: 11,
      revocation_generation: 3,
      invocation_iri: resource!(:tool_invocation, "invocation"),
      explicit_local_consent: false,
      managed_eligible: true
    }
  end

  defp request_attributes do
    %{
      operation: "repository.write",
      audience: "https://api.github.com",
      minimum_scopes: ["contents:write"],
      invocation_iri: resource!(:tool_invocation, "invocation"),
      managed_claim: false
    }
  end

  defp current(policy) do
    %{
      lease_state: :active,
      actor_iri: policy.actor_iri,
      delegated_agent_iri: policy.delegated_agent_iri,
      delegation_iri: policy.delegation_iri,
      repository_iri: policy.repository_iri,
      provider: policy.provider,
      attempt_iri: policy.attempt_iri,
      lease_iri: policy.lease_iri,
      fencing_token: policy.fencing_token,
      profile_revision: policy.profile_revision,
      credential_revision: policy.credential_revision,
      revocation_generation: policy.revocation_generation,
      invocation_iri: policy.invocation_iri
    }
  end

  defp resource!(seed), do: resource!(:knowledge_assertion, seed)

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h04-credential-#{seed}")
    iri
  end
end
