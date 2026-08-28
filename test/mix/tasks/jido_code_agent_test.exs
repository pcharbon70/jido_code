defmodule Mix.Tasks.JidoCode.AgentTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias JidoCode.Product.AgentOffering

  setup do
    test_pid = self()
    credential_path = temporary_path("credential")
    prior_path = System.get_env("JIDO_CODE_OPERATOR_CREDENTIAL_FILE")
    prior_gateway = Application.get_env(:jido_code, :agent_catalog_gateway)

    File.write!(credential_path, "test-operator-token\n")
    File.chmod!(credential_path, 0o600)
    System.put_env("JIDO_CODE_OPERATOR_CREDENTIAL_FILE", credential_path)

    Application.put_env(:jido_code, :agent_catalog_gateway, fn authority, identity, request ->
      send(test_pid, {:mix_agent_catalog, authority, identity, request})
      {:ok, [offering()]}
    end)

    on_exit(fn ->
      File.rm(credential_path)
      restore_system_env("JIDO_CODE_OPERATOR_CREDENTIAL_FILE", prior_path)
      restore_app_env(:agent_catalog_gateway, prior_gateway)
    end)

    :ok
  end

  test "reads a request from stdin and emits one machine-readable JSON object" do
    output =
      capture_io(Jason.encode!(catalog_params()), fn ->
        Mix.Task.reenable("jido_code.agent")
        Mix.Tasks.JidoCode.Agent.run(["catalog"])
      end)

    assert %{"outcome" => "admitted", "offerings" => [offering]} =
             output |> String.trim() |> Jason.decode!()

    assert offering["reference"] == "offering_1234567890"
    assert_receive {:mix_agent_catalog, authority, identity, request}
    assert authority.actor_iri == identity.actor_iri
    assert request["snapshot_ref"] == "snapshot_12345678"
  end

  test "accepts a protected request file but rejects semantic content in argv" do
    request_path = temporary_path("request")
    File.write!(request_path, Jason.encode!(catalog_params()))
    File.chmod!(request_path, 0o600)
    on_exit(fn -> File.rm(request_path) end)

    output =
      capture_io(fn ->
        Mix.Task.reenable("jido_code.agent")
        Mix.Tasks.JidoCode.Agent.run(["catalog", "--input", request_path])
      end)

    assert Jason.decode!(String.trim(output))["outcome"] == "admitted"
    assert_receive {:mix_agent_catalog, _, _, _}

    rejected =
      capture_io(fn ->
        Mix.Task.reenable("jido_code.agent")

        Mix.Tasks.JidoCode.Agent.run([
          "submit",
          "--input",
          request_path,
          "--intent",
          "task-content"
        ])
      end)

    assert Jason.decode!(String.trim(rejected)) == %{
             "outcome" => "rejected",
             "retry" => "never"
           }
  end

  defp catalog_params do
    %{
      "repository_ref" => "repository_123456",
      "snapshot_ref" => "snapshot_12345678",
      "task_class" => "focused_change",
      "language_class" => "elixir_phoenix",
      "capability_class" => "workspace_write_registered_checks",
      "rollout_stage" => "evaluation"
    }
  end

  defp offering do
    %AgentOffering{
      reference: "offering_1234567890",
      display_name: "Codex developer local",
      description: "Protected delegated coding agent",
      runtime_class: :delegated_cli,
      provider: :codex,
      deployment_class: :developer_local,
      authentication_kind: :existing_cli_session,
      billing_mode: :subscription,
      capability_class: :workspace_write_registered_checks,
      capability_summary: "Workspace writes and registered checks",
      task_classes: ["focused_change"],
      language_classes: ["elixir_phoenix"],
      readiness: :ready,
      readiness_age_seconds: 30,
      rollout_stage: :evaluation,
      profile_revision: 1,
      profile_digest: String.duplicate("a", 64),
      limitations: [:no_publication, :no_merge],
      selectable: true
    }
  end

  defp temporary_path(label) do
    Path.join(
      System.tmp_dir!(),
      "jido-code-agent-#{label}-#{System.unique_integer([:positive, :monotonic])}"
    )
  end

  defp restore_system_env(key, nil), do: System.delete_env(key)
  defp restore_system_env(key, value), do: System.put_env(key, value)
  defp restore_app_env(key, nil), do: Application.delete_env(:jido_code, key)
  defp restore_app_env(key, value), do: Application.put_env(:jido_code, key, value)
end
