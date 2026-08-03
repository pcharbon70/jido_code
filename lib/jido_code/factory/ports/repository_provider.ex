defmodule JidoCode.Factory.Ports.RepositoryProvider do
  @moduledoc """
  External repository-provider observation port.

  Implementations return normalized evidence and limitations only. They never
  choose graph placement, execute semantic commands, or accept claims.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Observations.ProviderObservation
  alias JidoCode.Factory.RepositoryLocator

  @type cursor :: String.t() | nil
  @type result ::
          {:ok, %{observations: [ProviderObservation.t()], next_cursor: cursor()}}
          | {:error, AdapterError.t()}

  @callback observe_repository(
              adapter :: term(),
              locator :: RepositoryLocator.t(),
              credential :: CredentialReference.t(),
              options :: keyword()
            ) :: result()

  @callback observe_collection(
              adapter :: term(),
              kind :: :issues | :pull_requests | :branches | :checks | :capabilities,
              locator :: RepositoryLocator.t(),
              credential :: CredentialReference.t(),
              cursor(),
              options :: keyword()
            ) :: result()
end
