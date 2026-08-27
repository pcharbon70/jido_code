defmodule JidoCode.Runtime.JidoHarness.CodexLocalRelease do
  @moduledoc "Closed developer-local security contract for the DGA1 Codex profile."

  @revision 1
  @provider_audience "https://api.openai.com/v1/"

  @spec manifest() :: map()
  def manifest do
    %{
      revision: @revision,
      profile_digest: JidoCode.Runtime.JidoHarness.CodexRelease.profile_digest(),
      adapter_release_digest: JidoCode.Runtime.JidoHarness.CodexRelease.digest(),
      deployment_class: :developer_local,
      authentication_kind: :existing_cli_session,
      billing_classification: :subscription,
      credential_delivery: :local_reference,
      provider_audience: @provider_audience,
      managed_eligible: false,
      background_dispatch: false,
      reusable_credential_export: false,
      revisions: %{
        readiness: digest("codex-local-readiness/v1"),
        credential: digest("codex-local-credential-reference/v1"),
        worker: digest("codex-local-worker/firecracker/v1"),
        sandbox: digest("codex-workspace-write-sandbox/v1"),
        network: digest("codex-openai-egress-broker/v1"),
        candidate_capture: digest("delegated-candidate-capture/v1"),
        check_registry: digest("jido-code-registered-checks/v1"),
        verifier: digest("fresh-checkout-verifier/v1"),
        policy: digest("delegated-local-policy/v1")
      }
    }
  end

  @spec digest() :: String.t()
  def digest, do: digest(manifest())

  @spec revisions() :: map()
  def revisions, do: manifest().revisions

  @spec provider_audience() :: String.t()
  def provider_audience, do: @provider_audience

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
