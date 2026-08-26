defmodule JidoCode.ManagedCodingRelease do
  @moduledoc "Final supported product boundary for the managed coding runtime."

  alias JidoCode.Knowledge.Error

  @contract_version "8.0.0"
  @historical_contract_version "7.0.0"
  @historical_digest "64b43c9786eb9c6d59de817aaa41f0efd287a0a7d08d84357bc604dc6f36e464"
  @production_profile "d2042eb2dfd52d1572cff7c7621042f37a524e113b3f266e0a2161ac8bec088d"
  @v7_disabled_features ~w[specialist_topology agent_os automatic_approval automatic_publication automatic_merge]a
  @disabled_features @v7_disabled_features ++ [:delegated_codex_selection]

  @spec manifest() :: map()
  def manifest do
    historical_manifest()
    |> Map.merge(%{
      contract_version: @contract_version,
      historical_contracts: %{@historical_contract_version => @historical_digest},
      runtime_classes: %{
        host_controlled: JidoCode.Runtime.ManagedCoding.Agent,
        delegated_cli: JidoCode.Runtime.JidoHarnessAdapter
      },
      delegated_profiles: %{
        codex_dga1: %{
          profile_digest: JidoCode.Runtime.JidoHarness.CodexRelease.profile_digest(),
          adapter_release_digest: JidoCode.Runtime.JidoHarness.CodexRelease.digest(),
          state: :disabled,
          deployment_class: :developer_local,
          executable_registry_key: "codex_cli"
        }
      },
      disabled_features: @disabled_features
    })
  end

  @spec manifest(String.t()) :: map() | nil
  def manifest(@contract_version), do: manifest()
  def manifest(@historical_contract_version), do: historical_manifest()
  def manifest(_version), do: nil

  defp historical_manifest do
    %{
      contract_version: @historical_contract_version,
      durable_authority: :triple_store,
      production_profile: "single_agent",
      production_profile_digest: @production_profile,
      specialist_topology: :rejected,
      specialist_code_posture: :evaluation_only,
      agent_os: :rejected,
      agent_os_adapter: :absent,
      pod_managers_in_default_supervision: false,
      public_api: JidoCode.Factory.ManagedCoding,
      runtime_effects: :factory_ports_only,
      verification: :independent_fresh_checkout,
      publication: :separate_human_authorized_boundary,
      merge_authority: :human_only,
      disabled_features: @v7_disabled_features,
      supported_workflow: [
        :admit,
        :start,
        :steer,
        :cancel,
        :status,
        :await,
        :handoff,
        :independent_verification,
        :human_decision,
        :human_merge
      ],
      post_plan_controls: %{
        availability_slo: 0.99,
        unsafe_effect_budget: 0,
        merge_authority_violations: 0,
        profile_review_days: 30,
        security_review_days: 90,
        capacity_review_days: 30,
        upgrade_requires_requalification: true
      }
    }
  end

  @spec digest() :: String.t()
  def digest do
    manifest()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec verify() :: :ok | {:error, Error.t()}
  def verify do
    release = manifest()
    historical = manifest(@historical_contract_version)

    with true <- release.production_profile == "single_agent",
         true <- release.specialist_topology == :rejected,
         true <- release.agent_os == :rejected,
         true <- release.agent_os_adapter == :absent,
         true <- release.pod_managers_in_default_supervision == false,
         true <- release.merge_authority == :human_only,
         true <- release.disabled_features == @disabled_features,
         true <- release.delegated_profiles.codex_dga1.state == :disabled,
         JidoCode.Runtime.JidoHarnessAdapter <- release.runtime_classes.delegated_cli,
         true <- digest(historical) == @historical_digest,
         true <- Application.spec(:jido_agent_os) == nil,
         true <- byte_size(digest()) == 64 do
      :ok
    else
      _invalid -> {:error, Error.new(:incompatible, :managed_coding_release)}
    end
  end

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
