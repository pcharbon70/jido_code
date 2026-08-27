defmodule JidoCode.Runtime.DelegatedAgentPhase03ReadinessTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.DelegatedAgentConsent
  alias JidoCode.Runtime.JidoHarness.CodexLocalRelease
  alias JidoCode.Runtime.JidoHarness.CodexReadiness
  alias JidoCode.TestSupport.FakeCodexExecutableRegistry
  alias JidoCode.TestSupport.FakeCodexReadinessProbe
  alias JidoCode.TestSupport.Phase04Fixture

  @now ~U[2026-08-26 17:00:00Z]

  test "discovers exact prompt-free readiness without claiming actor identity" do
    assert {:ok, receipt} = CodexReadiness.discover(readiness_attributes(), readiness_options())
    assert_received {:codex_login_status, executable}

    assert executable.sha256 ==
             JidoCode.Runtime.JidoHarness.CodexRelease.executable_sha256()

    assert receipt.profile == :codex_dga1
    assert receipt.ready
    assert receipt.discovery == :non_billable
    refute receipt.provider_request
    refute receipt.prompt_sent
    assert receipt.login.state == :authenticated
    assert receipt.login.actor_identity == :not_claimed
    assert receipt.login.provider_identity == :not_retained
    assert receipt.revisions == CodexLocalRelease.revisions()
    assert DateTime.diff(receipt.expires_at, receipt.observed_at) == 300
    refute inspect(receipt, limit: :infinity) =~ "token"
  end

  test "binds current readiness to expiry and every drift-sensitive component" do
    {:ok, receipt} = CodexReadiness.discover(readiness_attributes(), readiness_options())
    current = current_readiness(receipt)

    assert CodexReadiness.current?(receipt, current, @now)
    refute CodexReadiness.current?(receipt, current, receipt.expires_at)

    for field <- [
          :profile_digest,
          :adapter_release_digest,
          :local_release_digest,
          :executable_digest,
          :cli_version,
          :credential_generation,
          :revisions,
          :infrastructure
        ] do
      refute CodexReadiness.current?(receipt, Map.put(current, field, :drifted), @now)
    end
  end

  test "reports unavailable login and infrastructure without enabling readiness" do
    options = put_in(readiness_options(), [:probe_options, :result], {:ok, :unauthenticated})
    assert {:ok, receipt} = CodexReadiness.discover(readiness_attributes(), options)
    refute receipt.ready

    attributes = put_in(readiness_attributes(), [:infrastructure, :verifier, :ready], false)
    assert {:ok, receipt} = CodexReadiness.discover(attributes, readiness_options())
    refute receipt.ready
  end

  test "rejects unknown revisions, credential generations, and unbounded expiry" do
    assert {:error, _error} =
             CodexReadiness.discover(
               put_in(
                 readiness_attributes(),
                 [:infrastructure, :network, :revision],
                 digest("drift")
               ),
               readiness_options()
             )

    assert {:error, _error} =
             CodexReadiness.discover(
               %{readiness_attributes() | credential_generation: 0},
               readiness_options()
             )

    assert {:error, _error} =
             CodexReadiness.discover(
               readiness_attributes(),
               Keyword.put(readiness_options(), :ttl_seconds, 901)
             )
  end

  test "authorizes one exact foreground subscription effect" do
    assert {:ok, consent} = DelegatedAgentConsent.new(consent_attributes())
    current = consent_current(consent)

    assert {:ok, receipt} = DelegatedAgentConsent.authorize(consent, current, @now)
    assert receipt.effect_iri == consent.effect_iri
    assert receipt.billing_classification == :subscription
    assert receipt.credential_generation == consent.credential_generation

    durable = DelegatedAgentConsent.durable_record(consent)
    assert durable.attempt_iri == consent.attempt_iri
    assert durable.fencing_token == consent.fencing_token
    refute Map.has_key?(durable, :granted)
    refute Map.has_key?(durable, :billing_acknowledged)
    refute inspect(durable, limit: :infinity) =~ "local/codex/login"
  end

  test "rejects actor, repository, task, billing, generation, effect, and fence drift" do
    {:ok, consent} = DelegatedAgentConsent.new(consent_attributes())
    current = consent_current(consent)

    mutations = [
      &Map.put(&1, :actor_iri, resource("other-actor")),
      &Map.put(&1, :repository_iri, resource("other-repository")),
      &Map.put(&1, :task_iri, resource("other-task")),
      &Map.put(&1, :billing_terms_digest, digest("other-terms")),
      &Map.update!(&1, :credential_generation, fn value -> value + 1 end),
      &Map.put(&1, :effect_iri, resource("other-effect")),
      &Map.update!(&1, :fencing_token, fn value -> value + 1 end),
      &Map.put(&1, :foreground, false),
      &Map.put(&1, :background_dispatch, true)
    ]

    for mutation <- mutations do
      assert {:error, %{operation: :delegated_agent_consent}} =
               DelegatedAgentConsent.authorize(consent, mutation.(current), @now)
    end

    assert {:error, _error} =
             DelegatedAgentConsent.authorize(consent, current, consent.expires_at)
  end

  test "requires separate exact consent for live smoke and qualification effects" do
    {:ok, smoke} =
      consent_attributes()
      |> Map.merge(%{purpose: :live_smoke, effect_iri: resource("live-smoke")})
      |> DelegatedAgentConsent.new()

    {:ok, qualification} =
      consent_attributes()
      |> Map.merge(%{purpose: :qualification, effect_iri: resource("qualification")})
      |> DelegatedAgentConsent.new()

    refute smoke.iri == qualification.iri

    assert {:error, _error} =
             DelegatedAgentConsent.authorize(
               smoke,
               consent_current(qualification),
               @now
             )
  end

  test "retains only opaque login identity and revocation generation" do
    {:ok, reference} =
      CredentialReference.new(%{
        iri: resource("credential-reference"),
        provider: "codex",
        key: "local/codex/login"
      })

    assert CredentialReference.durable_record(reference, 7) == %{
             iri: reference.iri,
             provider: "codex",
             revocation_generation: 7
           }

    refute inspect(CredentialReference.durable_record(reference, 7)) =~ reference.key
  end

  defp readiness_options do
    [
      at: @now,
      ttl_seconds: 300,
      executable_registry: FakeCodexExecutableRegistry,
      probe: FakeCodexReadinessProbe,
      probe_options: [owner: self()]
    ]
  end

  defp readiness_attributes do
    revisions = CodexLocalRelease.revisions()

    %{
      credential_reference_iri: resource("credential-reference"),
      credential_generation: 7,
      infrastructure:
        Map.new([:worker, :sandbox, :network, :candidate_capture, :check_registry, :verifier], fn
          field -> {field, %{ready: true, revision: revisions[field]}}
        end)
    }
  end

  defp current_readiness(receipt) do
    Map.take(receipt, [
      :profile_digest,
      :adapter_release_digest,
      :local_release_digest,
      :executable_digest,
      :cli_version,
      :credential_reference_iri,
      :credential_generation,
      :revisions,
      :infrastructure
    ])
  end

  defp consent_attributes do
    %{
      actor_iri: resource("actor"),
      repository_iri: resource("repository"),
      task_iri: resource("task"),
      attempt_iri: resource("attempt"),
      lease_iri: resource("lease"),
      effect_iri: resource("execution"),
      fencing_token: 17,
      profile_digest: JidoCode.Runtime.JidoHarness.CodexRelease.profile_digest(),
      credential_reference_iri: resource("credential-reference"),
      credential_generation: 7,
      billing_classification: :subscription,
      billing_terms_digest: digest("subscription-terms-v1"),
      purpose: :execution,
      granted: true,
      billing_acknowledged: true,
      foreground: true,
      background_dispatch: false,
      managed_eligible: false,
      reusable_credential_export: false,
      granted_at: DateTime.add(@now, -60, :second),
      expires_at: DateTime.add(@now, 300, :second)
    }
  end

  defp consent_current(consent) do
    consent
    |> Map.from_struct()
    |> Map.take([
      :actor_iri,
      :repository_iri,
      :task_iri,
      :attempt_iri,
      :lease_iri,
      :effect_iri,
      :fencing_token,
      :profile_digest,
      :credential_reference_iri,
      :credential_generation,
      :billing_classification,
      :billing_terms_digest,
      :purpose
    ])
    |> Map.merge(%{
      lease_state: :active,
      foreground: true,
      background_dispatch: false,
      managed_eligible: false,
      reusable_credential_export: false
    })
  end

  defp resource(seed), do: Phase04Fixture.resource!("dca-phase-03-#{seed}")
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
