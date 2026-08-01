defmodule JidoCode.Factory.RepositoryLocator do
  @moduledoc """
  Factory-owned normalized locator value supplied to external adapter ports.

  Identity derivation delegates to the public Knowledge identity policy. The
  value grants no graph placement or command authority.
  """

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @derive {Inspect, only: [:iri, :provider_iri, :external_id, :state, :observed_at]}
  @enforce_keys [
    :iri,
    :provider_iri,
    :provider_host,
    :external_id,
    :canonical,
    :observed_address,
    :state,
    :observed_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @states ~w[active stale redirected inaccessible archived transferred deleted]a

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with {:ok, stable} <-
           Knowledge.repository_locator_identity(attributes[:provider], attributes[:external_id]),
         {:ok, address} <-
           Knowledge.repository_address(
             attributes[:provider],
             attributes[:owner],
             attributes[:name]
           ),
         {:ok, provider_iri} <- Knowledge.provider_identity(attributes[:provider]),
         [provider_host, _path] <- String.split(address.canonical, "/", parts: 2),
         state when state in @states <- attributes[:state],
         %DateTime{} = observed_at <- attributes[:observed_at] do
      {:ok,
       %__MODULE__{
         iri: stable.iri,
         provider_iri: provider_iri,
         provider_host: provider_host,
         external_id: String.trim(attributes[:external_id]),
         canonical: stable.canonical,
         observed_address: address.canonical,
         state: state,
         observed_at: DateTime.truncate(observed_at, :microsecond)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :factory_repository_locator)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :factory_repository_locator)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :factory_repository_locator)}
end
