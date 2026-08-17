defmodule JidoCode.Factory.Model.OAuthFileReference do
  @moduledoc "Explicit developer-local OAuth file enrollment without credential contents."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @derive {Inspect, only: [:iri, :provider, :expected_uid, :refresh_owner]}
  @enforce_keys [:iri, :provider, :path, :expected_uid, :refresh_owner, :deployment]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Knowledge.validate_resource_identity(attributes[:iri]),
         provider when provider in ["openai_codex", "anthropic"] <- attributes[:provider],
         path when is_binary(path) <- attributes[:path],
         true <- Path.type(path) == :absolute and byte_size(path) <= 1_024,
         uid when is_integer(uid) and uid >= 0 <- attributes[:expected_uid],
         :req_llm <- attributes[:refresh_owner],
         :developer_local <- attributes[:deployment] do
      {:ok,
       %__MODULE__{
         iri: attributes.iri,
         provider: provider,
         path: Path.expand(path),
         expected_uid: uid,
         refresh_owner: :req_llm,
         deployment: :developer_local
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :oauth_file_reference)}
end
