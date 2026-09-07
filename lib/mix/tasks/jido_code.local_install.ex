defmodule Mix.Tasks.JidoCode.LocalInstall do
  @shortdoc "Bootstrap a pristine local production installation for one named human"
  @moduledoc """
  Run with `MIX_ENV=prod mix jido_code.local_install --confirm INITIALIZE`.
  Requires the local profile, private store/identity configuration, operator token,
  and JIDO_CODE_HUMAN_BOOTSTRAP_LOGIN, DISPLAY_NAME and CREDENTIAL variables.
  Never pass credentials on the command line. Start the HTTP server only after
  this ceremony succeeds. Existing datasets and consumed identity bootstrap fail
  closed; they are never reset by this task.
  """
  use Mix.Task

  def run(["--confirm", "INITIALIZE"]) do
    Mix.Task.run("app.start")

    attributes = %{
      login: required!("JIDO_CODE_HUMAN_BOOTSTRAP_LOGIN"),
      display_name: required!("JIDO_CODE_HUMAN_BOOTSTRAP_DISPLAY_NAME")
    }

    case JidoCode.LocalInstall.bootstrap(
           attributes,
           required!("JIDO_CODE_HUMAN_BOOTSTRAP_CREDENTIAL"),
           required!("JIDO_CODE_OPERATOR_TOKEN")
         ) do
      {:ok, _receipt} ->
        Mix.shell().info("Local named-human and graph bootstrap completed.")

      {:error, _} ->
        Mix.raise(
          "Local bootstrap failed; preserve both stores and consult the recovery runbook."
        )
    end
  end

  def run(_), do: Mix.raise("usage: mix jido_code.local_install --confirm INITIALIZE")

  defp required!(name) do
    case System.get_env(name) do
      value when is_binary(value) and value != "" -> value
      _ -> Mix.raise("#{name} is required")
    end
  end
end
