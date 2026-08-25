defmodule JidoCode.TestSupport.FakeManagedCodingVerifier do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ManagedCodingVerifier

  @impl true
  def verify(agent, request, _options) do
    state = Agent.get(agent, & &1)
    send(state.owner, {:verify, request})

    case Map.get(state, :result) do
      result when is_function(result, 1) -> result.(request)
      nil -> default_result(request)
      result -> result
    end
  end

  defp default_result(request) do
    {:ok,
     %{
       candidate_digest: request.candidate_digest,
       verifier_profile_revision: request.verifier_profile_revision,
       environment_revision: request.environment_revision,
       toolchain_revision: request.toolchain_revision,
       policy_revision: request.policy_revision,
       status: :passed,
       checks:
         Enum.map(request.checks, fn check ->
           %{
             id: check.id,
             status: :passed,
             result_digest: digest("result-#{check.id}"),
             log_artifact_iri: iri("log-#{check.id}"),
             resource_observation_iri: iri("resource-#{check.id}")
           }
         end),
       evidence_iris: [iri("verification-evidence")],
       evidence_digest: digest("evidence"),
       completed_at: DateTime.add(request.deadline, -1, :second)
     }}
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
