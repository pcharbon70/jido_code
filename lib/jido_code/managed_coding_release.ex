defmodule JidoCode.ManagedCodingRelease do
  @moduledoc "Final supported product boundary for the managed coding runtime."

  alias JidoCode.Knowledge.Error

  @contract_version "7.0.0"
  @production_profile "d2042eb2dfd52d1572cff7c7621042f37a524e113b3f266e0a2161ac8bec088d"
  @disabled_features ~w[specialist_topology agent_os automatic_approval automatic_publication automatic_merge]a

  @spec manifest() :: map()
  def manifest do
    %{
      contract_version: @contract_version,
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
      disabled_features: @disabled_features,
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

    with true <- release.production_profile == "single_agent",
         true <- release.specialist_topology == :rejected,
         true <- release.agent_os == :rejected,
         true <- release.agent_os_adapter == :absent,
         true <- release.pod_managers_in_default_supervision == false,
         true <- release.merge_authority == :human_only,
         true <- release.disabled_features == @disabled_features,
         true <- Application.spec(:jido_agent_os) == nil,
         true <- byte_size(digest()) == 64 do
      :ok
    else
      _invalid -> {:error, Error.new(:incompatible, :managed_coding_release)}
    end
  end
end
