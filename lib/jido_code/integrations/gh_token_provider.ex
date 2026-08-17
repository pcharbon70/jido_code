defmodule JidoCode.Integrations.GhTokenProvider do
  @moduledoc "Developer-local `gh auth token` adapter returning bytes only to the model call."

  @behaviour JidoCode.Factory.Ports.SecretProvider

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference

  @derive {Inspect, only: []}
  @enforce_keys [:runner]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(keyword()) :: {:ok, t()}
  def new(options \\ []) do
    runner = Keyword.get(options, :runner, &run_gh/0)
    {:ok, %__MODULE__{runner: runner}}
  end

  @impl true
  def fetch(
        %__MODULE__{runner: runner},
        %CredentialReference{provider: "github_copilot", key: "gh-auth-token"}
      )
      when is_function(runner, 0) do
    case runner.() do
      {token, 0} when is_binary(token) ->
        token = String.trim(token)

        if byte_size(token) in 1..8_192,
          do: {:ok, token},
          else: {:error, AdapterError.new(:unauthorized, :gh_auth_token)}

      _error ->
        {:error, AdapterError.new(:unauthorized, :gh_auth_token)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :gh_auth_token)}
  end

  def fetch(_provider, _credential),
    do: {:error, AdapterError.new(:invalid_input, :gh_auth_token)}

  defp run_gh, do: System.cmd("gh", ["auth", "token"], stderr_to_stdout: true)
end
