defmodule Mix.Tasks.Identity.Bootstrap do
  @shortdoc "Performs the one-time local named-human bootstrap ceremony"

  @moduledoc """
  Creates the first named human in an explicitly configured identity store.

  The task reads `JIDO_CODE_HUMAN_BOOTSTRAP_LOGIN`,
  `JIDO_CODE_HUMAN_BOOTSTRAP_DISPLAY_NAME`, and
  `JIDO_CODE_HUMAN_BOOTSTRAP_CREDENTIAL` from the local process environment.
  The credential is never printed or written to application configuration.
  """

  use Mix.Task

  @impl true
  def run(_arguments) do
    Mix.Task.run("app.start")

    attributes = %{
      login: required!("JIDO_CODE_HUMAN_BOOTSTRAP_LOGIN"),
      display_name: required!("JIDO_CODE_HUMAN_BOOTSTRAP_DISPLAY_NAME")
    }

    credential = required!("JIDO_CODE_HUMAN_BOOTSTRAP_CREDENTIAL")

    case JidoCode.Identity.bootstrap(attributes, credential, local_ceremony: true) do
      {:ok, account} ->
        Mix.shell().info("Created named human #{account.subject_ref}; bootstrap is now consumed.")

      {:error, reason} ->
        Mix.raise("named-human bootstrap failed: #{reason}")
    end
  end

  defp required!(name) do
    case System.get_env(name) do
      value when is_binary(value) and value != "" -> value
      _missing -> Mix.raise("#{name} is required")
    end
  end
end
