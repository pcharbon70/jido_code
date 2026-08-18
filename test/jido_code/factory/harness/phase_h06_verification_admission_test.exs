defmodule JidoCode.Factory.Harness.PhaseH06VerificationAdmissionTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Verification.Admission

  @digest String.duplicate("ab", 32)

  test "admits only an exact committed closed-run projection" do
    assert {:ok, admission} = Admission.admit(attributes())
    assert admission.assessment_availability == :available
    assert Admission.accepting_evidence?(admission)
    assert byte_size(admission.input_digest) == 64

    for mutation <- [
          %{finalization_receipt: %{receipt() | outcome: :already_committed}},
          %{attempt_iri: iri("attempt/other")},
          %{run_graph_revision: 13},
          %{terminal_sequence: 42},
          %{accepted_reference_sets: %{artifact: [iri("artifact/other")]}}
        ] do
      assert {:error, error} = Admission.admit(Map.merge(attributes(), mutation))
      assert error.kind == :invalid_input
    end
  end

  test "binds every immutable verifier input into the input digest" do
    {:ok, original} = Admission.admit(attributes())

    mutations = [
      %{fencing_token: 8},
      %{control_graph_revision: 4},
      %{base_commit: String.duplicate("c", 40)},
      %{base_snapshot_digest: String.duplicate("cd", 32)},
      %{patch_digest: String.duplicate("de", 32)},
      %{verification_environment_digest: String.duplicate("ef", 32)},
      %{policy_revision: "policy-2"},
      %{rubric_revision: "rubric-2"},
      %{evaluator_capability_iri: iri("capability/other")}
    ]

    for mutation <- mutations do
      assert {:ok, changed} = Admission.admit(Map.merge(attributes(), mutation))
      refute changed.input_digest == original.input_digest
    end
  end

  test "incomplete runs are unavailable or inconclusive and never accepting" do
    incomplete =
      attributes()
      |> Map.merge(%{completeness: :incomplete, missing_classes: [:sandbox_output]})
      |> put_in([:finalization_receipt, :completeness], :incomplete)

    assert {:ok, unavailable} = Admission.admit(incomplete)
    assert Admission.assessment_availability(unavailable) == :unavailable
    refute Admission.accepting_evidence?(unavailable)

    permitted = Map.put(incomplete, :policy_verifiable_missing_classes, [:sandbox_output])
    assert {:ok, inconclusive} = Admission.admit(permitted)
    assert Admission.assessment_availability(inconclusive) == :inconclusive
    refute Admission.accepting_evidence?(inconclusive)
  end

  test "rejects executor self-verification and malformed artifact bindings" do
    assert {:error, error} =
             attributes()
             |> Map.put(:evaluator_iri, iri("actor/executor"))
             |> Admission.admit()

    assert error.operation == :verification_admission

    assert {:error, _error} =
             attributes()
             |> put_in([:candidate_artifacts, Access.at(0), :byte_count], -1)
             |> Admission.admit()
  end

  defp attributes do
    %{
      finalization_receipt: receipt(),
      attempt_iri: iri("attempt/1"),
      lease_iri: iri("lease/1"),
      fencing_token: 7,
      run_graph_iri: run_graph(),
      run_graph_revision: 12,
      terminal_sequence: 41,
      completeness: :complete,
      missing_classes: [],
      accepted_reference_sets: %{artifact: [iri("artifact/patch")]},
      source_graph_revisions: %{
        source_graph() => 9
      },
      control_graph_iri: control_graph(),
      control_graph_revision: 3,
      base_commit: String.duplicate("b", 40),
      base_snapshot_digest: @digest,
      candidate_artifacts: [
        %{
          iri: iri("artifact/patch"),
          digest: @digest,
          media_type: "application/vnd.jido.patch",
          byte_count: 1_024
        }
      ],
      patch_digest: @digest,
      verification_environment_digest: @digest,
      policy_revision: "policy-1",
      rubric_revision: "rubric-1",
      evaluator_iri: iri("actor/verifier"),
      evaluator_capability_iri: iri("capability/verify"),
      execution_actor_iri: iri("actor/executor"),
      policy_verifiable_missing_classes: []
    }
  end

  defp receipt do
    %{
      iri: iri("receipt/finalize-1"),
      command_type: "FinalizeExecutionRun",
      outcome: :committed,
      attempt_iri: iri("attempt/1"),
      run_graph_iri: run_graph(),
      run_graph_revision: 12,
      terminal_sequence: 41,
      completeness: :complete,
      accepted_reference_sets: %{artifact: [iri("artifact/patch")]}
    }
  end

  defp iri(path), do: "https://jido.run/id/phase-h06/#{path}"
  defp run_graph, do: "https://jido.run/graph/run/" <> String.duplicate("a", 32)

  defp source_graph do
    "https://jido.run/graph/repo/" <>
      String.duplicate("b", 32) <> "/source/" <> String.duplicate("c", 32)
  end

  defp control_graph do
    "https://jido.run/graph/repo/" <> String.duplicate("b", 32) <> "/control"
  end
end
