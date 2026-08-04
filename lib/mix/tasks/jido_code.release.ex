defmodule Mix.Tasks.JidoCode.Release do
  @moduledoc "Verifies the exact release contract, upgrade preflight, or architecture audit."

  use Mix.Task

  alias JidoCode.Knowledge.Admin
  alias JidoCode.Knowledge.Migrations.Workflow
  alias JidoCode.ReleaseAudit
  alias JidoCode.ReleaseContract

  @shortdoc "Run release verification and operational preflight"

  @impl true
  def run(["verify"]) do
    Mix.Task.run("app.start")
    :ok = accepted!(ReleaseContract.verify())

    print(%{
      status: :accepted,
      digest: ReleaseContract.digest(),
      manifest: ReleaseContract.manifest()
    })
  end

  def run(["audit"]) do
    Mix.Task.run("app.start")
    {:ok, audit} = accepted!(ReleaseAudit.run())
    print(audit)
  end

  def run(["preflight"]) do
    Mix.Task.run("app.start")
    :ok = accepted!(ReleaseContract.verify())
    {:ok, health} = accepted!(Admin.execute(:health))
    {:ok, integrity} = accepted!(Admin.execute(:integrity))
    {:ok, backup} = accepted!(Admin.execute(:backup))
    manifest = ReleaseContract.manifest()

    {:ok, plan} =
      accepted!(Workflow.plan(manifest, manifest, estimated_bytes: backup.payload_bytes))

    {:ok, preflight} =
      accepted!(
        Workflow.preflight(plan, %{
          integrity: integrity,
          backup: backup,
          free_bytes: 0,
          maintenance_available?: health.ready?
        })
      )

    print(%{status: :accepted, health: health, backup: backup, plan: plan, preflight: preflight})
  end

  def run(_arguments),
    do: Mix.raise("usage: mix jido_code.release verify|preflight|audit")

  defp accepted!(:ok), do: :ok
  defp accepted!({:ok, value}), do: {:ok, value}

  defp accepted!({:error, error}) do
    Mix.raise("release verification failed: #{error.kind}/#{error.operation}")
  end

  defp print(value) do
    value
    |> json_value()
    |> Jason.encode!(pretty: true)
    |> Mix.shell().info()
  end

  defp json_value(value) when is_struct(value), do: value |> Map.from_struct() |> json_value()

  defp json_value(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {key, json_value(item)} end)

  defp json_value(value) when is_list(value), do: Enum.map(value, &json_value/1)
  defp json_value(value) when is_tuple(value), do: value |> Tuple.to_list() |> json_value()
  defp json_value(value), do: value
end
