defmodule JidoCode.Runtime.JidoHarness.CodexLocalReadinessProbe do
  @moduledoc "Non-billable local Codex login-status probe with bounded redacted output."

  @behaviour JidoCode.Runtime.JidoHarness.CodexReadinessProbe

  @impl true
  def login_status(%{path: path, installation_root: root}, options)
      when is_binary(path) and is_binary(root) and is_list(options) do
    environment = Keyword.get(options, :environment, [])

    case System.cmd(path, ["login", "status"],
           cd: root,
           env: environment,
           stderr_to_stdout: true
         ) do
      {output, 0} when byte_size(output) <= 4_096 ->
        {:ok, classify(output)}

      {output, _status} when byte_size(output) <= 4_096 ->
        {:ok, if(login_absent?(output), do: :unauthenticated, else: :unknown)}

      _invalid ->
        {:error, :unbounded_login_status}
    end
  rescue
    _error -> {:error, :login_status_unavailable}
  end

  def login_status(_executable, _options), do: {:error, :invalid_login_status_probe}

  defp classify(output) do
    if login_absent?(output), do: :unauthenticated, else: :authenticated
  end

  defp login_absent?(output),
    do: Regex.match?(~r/(?:not logged in|unauthenticated|login required|no credentials)/i, output)
end
