defmodule JidoCode.Factory.Evaluation.Track do
  @moduledoc "Closed catalog of Phase 7 evaluation tracks."

  @contract_version "1.0.0"
  @tracks [
    %{
      id: :access_profile_conformance,
      class: :conformance,
      corpus: :deterministic,
      rollout_evidence?: true
    },
    %{
      id: :req_llm_provider_contract,
      class: :conformance,
      corpus: :deterministic,
      rollout_evidence?: true
    },
    %{
      id: :jido_harness_cli_contract,
      class: :conformance,
      corpus: :deterministic,
      rollout_evidence?: true
    },
    %{
      id: :harness_conformance,
      class: :conformance,
      corpus: :deterministic,
      rollout_evidence?: true
    },
    %{id: :editing_reliability, class: :capability, corpus: :private, rollout_evidence?: true},
    %{id: :retrieval, class: :capability, corpus: :private, rollout_evidence?: true},
    %{
      id: :swe_bench_verified,
      class: :interoperability,
      corpus: :public,
      rollout_evidence?: false
    },
    %{
      id: :fresh_private_issues,
      class: :release_gate,
      corpus: :fresh_private,
      rollout_evidence?: true
    },
    %{
      id: :terminal_workload,
      class: :interoperability,
      corpus: :reviewed_public,
      rollout_evidence?: false
    },
    %{id: :flaky_test, class: :reliability, corpus: :private, rollout_evidence?: true},
    %{id: :production_shadow, class: :shadow, corpus: :private, rollout_evidence?: true},
    %{id: :pull_request_pilot, class: :pilot, corpus: :private, rollout_evidence?: true}
  ]

  @type id ::
          :access_profile_conformance
          | :req_llm_provider_contract
          | :jido_harness_cli_contract
          | :harness_conformance
          | :editing_reliability
          | :retrieval
          | :swe_bench_verified
          | :fresh_private_issues
          | :terminal_workload
          | :flaky_test
          | :production_shadow
          | :pull_request_pilot

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec all() :: [map()]
  def all, do: @tracks

  @spec ids() :: [id()]
  def ids, do: Enum.map(@tracks, & &1.id)

  @spec fetch(id()) :: {:ok, map()} | :error
  def fetch(id), do: Enum.find_value(@tracks, :error, &if(&1.id == id, do: {:ok, &1}))

  @spec rollout_evidence?(id()) :: boolean()
  def rollout_evidence?(id) do
    case fetch(id) do
      {:ok, track} -> track.rollout_evidence?
      :error -> false
    end
  end
end
