defmodule JidoCode.Integrations.OAuthFileProvider do
  @moduledoc "Explicit OAuth-file credential provider with validation on every release."

  @behaviour JidoCode.Factory.Ports.SecretProvider

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Model.OAuthFileReference
  alias JidoCode.Integrations.OAuthFileEnrollment

  @derive {Inspect, only: []}
  @enforce_keys [:references, :forbidden_roots]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(%{String.t() => OAuthFileReference.t()}, [String.t()]) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def new(references, forbidden_roots) when is_map(references) and is_list(forbidden_roots) do
    if map_size(references) > 0 and
         Enum.all?(references, fn {key, value} ->
           is_binary(key) and match?(%OAuthFileReference{}, value)
         end) do
      {:ok, %__MODULE__{references: references, forbidden_roots: forbidden_roots}}
    else
      invalid(:oauth_file_provider)
    end
  end

  def new(_references, _forbidden_roots), do: invalid(:oauth_file_provider)

  @impl true
  def fetch(%__MODULE__{} = provider, %CredentialReference{} = credential) do
    with {:ok, %OAuthFileReference{} = reference} <-
           Map.fetch(provider.references, credential.key),
         true <- reference.provider == credential.provider,
         :ok <-
           OAuthFileEnrollment.validate(reference,
             forbidden_roots: provider.forbidden_roots
           ) do
      {:ok, reference.path}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:oauth_file_fetch)
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :oauth_file_fetch)}
  end

  def fetch(_provider, _credential), do: invalid(:oauth_file_fetch)

  defp invalid(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end
