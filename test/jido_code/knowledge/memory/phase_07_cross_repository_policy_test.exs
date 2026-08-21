defmodule JidoCode.Knowledge.Memory.Phase07CrossRepositoryPolicyTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Memory.CrossRepositoryAudit
  alias JidoCode.Knowledge.Memory.CrossRepositoryAuthorization
  alias JidoCode.Knowledge.Memory.CrossRepositoryPolicy
  alias JidoCode.Knowledge.ResourceIdentity

  @cutoff ~U[2026-08-01 00:00:00Z]
  @valid_from ~U[2026-08-02 00:00:00Z]
  @now ~U[2026-08-03 00:00:00Z]
  @expires_at ~U[2026-09-01 00:00:00Z]

  test "requires an explicit expiring cohort, actors, classes, and erasure generations" do
    assert {:ok, authorization} = authorization()
    assert authorization.repository_iris == Enum.sort(repositories())
    assert authorization.actor_iris == [actor()]
    assert authorization.data_classes == [:experience_record, :personal]
    assert authorization.erasure_generations == generations()

    assert CrossRepositoryAuthorization.current?(
             authorization,
             actor(),
             :dataset_construction,
             :query,
             @now
           )

    statements = CrossRepositoryAuthorization.statements(authorization)
    assert Enum.any?(statements, fn {subject, _, _} -> subject == authorization.iri end)

    refute Enum.any?(statements, fn {_subject, _predicate, object} ->
             inspect(object) =~ "protected-payload-canary"
           end)

    assert {:error, %{kind: :invalid_input}} =
             authorization(%{erasure_generations: %{Enum.at(repositories(), 0) => 0}})

    assert {:ok, revoked} = CrossRepositoryAuthorization.revoke(authorization, @now, 1)

    refute CrossRepositoryAuthorization.current?(
             revoked,
             actor(),
             :dataset_construction,
             :query,
             @now
           )
  end

  test "partitions before enumeration and conceals unauthorized repository influence" do
    assert {:ok, authorization} = authorization()
    [first, second] = repositories()
    key = CrossRepositoryPolicy.partition_key(authorization)

    eligible = %{
      iri: resource(:experience_case, "eligible"),
      repository_iri: first,
      classification: :experience_record,
      erasure_generation: 3,
      effective_at: @cutoff,
      non_authoritative?: true
    }

    indexes = %{
      key => [eligible],
      "unauthorized-partition" => [
        %{eligible | repository_iri: resource(:repository_snapshot, "denied")}
      ]
    }

    request = %{
      actor_iri: actor(),
      purpose: :dataset_construction,
      use: :candidate_generation,
      repository_iris: [first, second],
      data_class: :experience_record
    }

    assert {:ok, [^eligible]} =
             CrossRepositoryPolicy.candidates(authorization, indexes, request, @now)

    denied_request = %{request | repository_iris: [resource(:repository_snapshot, "denied")]}

    assert {:error, %{kind: :unauthorized}} =
             CrossRepositoryPolicy.candidates(authorization, indexes, denied_request, @now)

    assert {:error, %{kind: :unauthorized}} =
             CrossRepositoryPolicy.candidates(
               authorization,
               indexes,
               %{request | data_class: :confidential},
               @now
             )
  end

  test "keeps imported cases advisory until independent target-repository acceptance" do
    candidate = %{
      iri: resource(:experience_case, "candidate"),
      repository_iri: Enum.at(repositories(), 0),
      non_authoritative?: true
    }

    target = Enum.at(repositories(), 1)

    assert {:ok, unaccepted} = CrossRepositoryPolicy.local_authority(candidate, target, %{})
    refute unaccepted.local_authority?

    acceptance = %{
      accepted?: true,
      target_repository_iri: target,
      decision_iri: resource(:authorization_grant, "local-decision"),
      independent?: true
    }

    assert {:ok, accepted} =
             CrossRepositoryPolicy.local_authority(candidate, target, acceptance)

    assert accepted.local_authority?
    assert accepted.local_decision_iri == acceptance.decision_iri
  end

  test "audits allowed and denied operations without protected payload fields" do
    assert {:ok, authorization} = authorization()

    attributes = %{
      authorization_iri: authorization.iri,
      actor_iri: actor(),
      operation: :denial,
      status: :denied,
      repository_iris: repositories(),
      selected_resource_iris: [],
      omitted_count: 1,
      reason: "requested classification was not expressly authorized",
      recorded_at: @now
    }

    assert {:ok, audit} = CrossRepositoryAudit.new(attributes)
    assert audit.selected_resource_iris == []
    assert [_first | _rest] = CrossRepositoryAudit.statements(audit)

    assert {:error, %{kind: :invalid_input}} =
             CrossRepositoryAudit.new(Map.put(attributes, :payload, "protected-payload-canary"))
  end

  test "pins the versioned policy command boundary" do
    assert CommandRegistry.dataset_policy_version() == "2.4.0"

    for command <- [
          "AuthorizeCrossRepositoryUse",
          "RecordCrossRepositoryAudit",
          "RevokeCrossRepositoryUse"
        ] do
      assert {:ok, definition} =
               CommandRegistry.resolve(command, CommandRegistry.dataset_policy_version())

      assert definition.capability == :dataset_policy_writer
    end

    assert :dataset_policy_writer in Authorization.capabilities()
  end

  defp authorization(overrides \\ %{}) do
    defaults = %{
      cohort_iri: resource(:repository_cohort, "phase-7-cohort"),
      repository_iris: repositories(),
      actor_iris: [actor()],
      purpose: :dataset_construction,
      allowed_uses: [:query, :candidate_generation, :dataset_construction],
      data_classes: [:experience_record, :personal],
      effective_cutoff: @cutoff,
      valid_from: @valid_from,
      expires_at: @expires_at,
      policy_revision: "2.0.0",
      decision_iri: resource(:authorization_grant, "phase-7-decision"),
      decision: :authorized,
      erasure_generations: generations()
    }

    CrossRepositoryAuthorization.new(Map.merge(defaults, overrides))
  end

  defp repositories do
    [
      resource(:repository_snapshot, "phase-7-repository-a"),
      resource(:repository_snapshot, "phase-7-repository-b")
    ]
  end

  defp generations do
    [first, second] = repositories()
    %{first => 3, second => 7}
  end

  defp actor, do: resource(:authorization_grant, "phase-7-actor")

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end
