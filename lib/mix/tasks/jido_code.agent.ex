defmodule Mix.Tasks.JidoCode.Agent do
  use Mix.Task

  alias JidoCode.Product.AgentCLI
  alias JidoCode.Product.ProtectedInput

  @shortdoc "Use authenticated coding-agent product workflows"
  @credential_file_env "JIDO_CODE_OPERATOR_CREDENTIAL_FILE"
  @commands ~w[catalog submit show steer answer cancel handoff recovery]
  @switches [input: :string]

  @moduledoc """
  Runs one authenticated coding-agent product command and emits bounded JSON.

      mix jido_code.agent catalog < request.json
      mix jido_code.agent submit --input protected-request.json
      mix jido_code.agent show < request.json
      mix jido_code.agent steer < request.json
      mix jido_code.agent answer < request.json
      mix jido_code.agent cancel < request.json
      mix jido_code.agent handoff < request.json
      mix jido_code.agent recovery < request.json

  Requests are accepted only from stdin or a regular file with no group or
  other permission bits. Semantic task content and credentials are never
  accepted in command arguments. Set `#{@credential_file_env}` to a protected
  regular file containing the existing local operator credential.
  """

  @impl Mix.Task
  def run(arguments) do
    Mix.Task.run("app.start")

    result =
      with {:ok, command, input_path} <- parse_arguments(arguments),
           {:ok, request_bytes} <- request_bytes(input_path),
           {:ok, request} <- decode_request(request_bytes),
           {:ok, credential_path} <- credential_path(),
           {:ok, credential} <- ProtectedInput.credential_from_file(credential_path) do
        AgentCLI.execute(command, request, credential)
      else
        {:error, :unauthorized} -> {:error, %{outcome: "unauthorized", retry: "never"}}
        {:error, :unavailable} -> {:error, %{outcome: "unavailable", retry: "retry"}}
        _invalid -> {:error, %{outcome: "rejected", retry: "never"}}
      end

    result
    |> elem(1)
    |> Jason.encode!()
    |> Mix.shell().info()
  end

  defp parse_arguments(arguments) do
    case OptionParser.parse(arguments, strict: @switches) do
      {options, [command], []} when command in @commands ->
        if Keyword.keys(options) in [[], [:input]],
          do: {:ok, command, Keyword.get(options, :input)},
          else: {:error, :invalid_input}

      _invalid ->
        {:error, :invalid_input}
    end
  end

  defp request_bytes(nil), do: ProtectedInput.request_from_stdin()
  defp request_bytes(path), do: ProtectedInput.request_from_file(path)

  defp decode_request(bytes) do
    case Jason.decode(bytes) do
      {:ok, request} when is_map(request) -> {:ok, request}
      _invalid -> {:error, :invalid_input}
    end
  end

  defp credential_path do
    case System.get_env(@credential_file_env) do
      path when is_binary(path) and byte_size(path) in 1..4_096 -> {:ok, path}
      _missing -> {:error, :unauthorized}
    end
  end
end
