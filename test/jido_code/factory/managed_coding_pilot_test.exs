defmodule JidoCode.Factory.ManagedCodingPilotTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Pilot
  alias JidoCode.TestSupport.FakeManagedCodingDraftPublisher, as: Publisher

  @digest String.duplicate("a", 64)

  test "enforces allowlists, profile, volume, business hours, on-call, and opt-out" do
    state = pilot()
    assert {:ok, enrollment, state} = Pilot.enroll(state, request(), ~U[2026-08-26 14:00:00Z])
    assert enrollment.publication_scope == :draft_only
    assert enrollment.opt_out_documented

    assert {:error, %AdapterError{kind: :unauthorized}, _state} =
             Pilot.enroll(state, request("late"), ~U[2026-08-26 23:00:00Z])

    opted_out = %{request("opted") | repository_iri: iri("opted-out")}

    assert {:error, %AdapterError{kind: :unauthorized}, _state} =
             Pilot.enroll(state, opted_out, ~U[2026-08-26 14:00:00Z])
  end

  test "publishes only accepted candidates as protected human-reviewed drafts" do
    {state, enrollment} = enrolled()

    assert {:ok, publication, state} =
             Pilot.publish(Publisher, self(), state, enrollment, candidate())

    assert publication.draft
    assert publication.human_review_required
    assert publication.repository_protections_required
    refute publication.approval_authority
    refute publication.merge_authority
    assert_receive {:draft_publication, request, []}
    assert request.candidate_digest == @digest

    rejected = %{candidate() | status: :rejected}

    assert {:error, %AdapterError{kind: :unauthorized}, _state} =
             Pilot.publish(Publisher, self(), state, enrollment, rejected)
  end

  test "records human modifications separately and stops/quarantines on threshold breach" do
    {state, enrollment} = enrolled()
    {:ok, publication, state} = Pilot.publish(Publisher, self(), state, enrollment, candidate())
    outcome = outcome()
    assert {:ok, state} = Pilot.record_human_outcome(state, publication, outcome)
    [record] = state.outcomes
    assert record.candidate_attribution_excludes_human_changes
    assert record.human_change_digest != record.candidate_digest

    unsafe =
      outcome()
      |> put_in([:metrics, :unsafe_behavior], 1)
      |> Map.put(:signals, [:safety])

    assert {:ok, stopped} = Pilot.record_human_outcome(state, publication, unsafe)
    assert stopped.status == :stopped
    assert :safety in stopped.stop_reasons
    assert Enum.all?(stopped.publications, &(&1.status == :quarantined))
  end

  defp enrolled do
    state = pilot()
    {:ok, enrollment, state} = Pilot.enroll(state, request(), ~U[2026-08-26 14:00:00Z])
    {state, enrollment}
  end

  defp pilot do
    {:ok, state} =
      Pilot.new(%{
        profile_digest: @digest,
        tenant_iris: [iri("tenant")],
        repository_iris: [iri("repository"), iri("opted-out")],
        task_classes: ["defect_repair"],
        volume_ceiling: 10,
        business_hours: %{start_hour: 9, end_hour: 18},
        on_call_actor_iris: [iri("on-call")],
        opt_out_repository_iris: [iri("opted-out")],
        thresholds: %{
          acceptance: 1,
          edit_distance: 500,
          review_minutes: 120,
          escaped_regression: 0,
          reopen_revert: 0,
          unsafe_behavior: 0,
          abstention: 1,
          latency_ms: 10_000,
          cost_microunits: 20_000,
          operator_minutes: 120
        }
      })

    state
  end

  defp request(suffix \\ "attempt") do
    %{
      attempt_iri: iri(suffix),
      tenant_iri: iri("tenant"),
      repository_iri: iri("repository"),
      task_iri: iri("task-#{suffix}"),
      task_class: "defect_repair",
      cohort: "small-elixir",
      profile_digest: @digest,
      actor_iri: iri("actor"),
      on_call_actor_iri: iri("on-call")
    }
  end

  defp candidate do
    %{
      status: :accepted,
      candidate_iri: iri("candidate"),
      candidate_digest: @digest,
      verification_iri: iri("verification"),
      verification_digest: @digest,
      profile_digest: @digest,
      limitations: ["human review required"]
    }
  end

  defp outcome do
    %{
      reviewer_actor_iri: iri("reviewer"),
      approved: true,
      merged: true,
      human_change_digest: String.duplicate("b", 64),
      metrics: %{
        acceptance: 1,
        edit_distance: 10,
        review_minutes: 15,
        escaped_regression: 0,
        reopen_revert: 0,
        unsafe_behavior: 0,
        abstention: 0,
        latency_ms: 1_000,
        cost_microunits: 5_000,
        operator_minutes: 20
      },
      signals: []
    }
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
