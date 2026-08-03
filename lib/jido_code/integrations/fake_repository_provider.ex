defmodule JidoCode.Integrations.FakeRepositoryProvider do
  @moduledoc """
  Deterministic provider adapter for pagination, redirect, rate-limit,
  credential, deletion, stale revision, and transient-failure tests.
  """

  @behaviour JidoCode.Factory.Ports.RepositoryProvider

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Observations.ProviderObservation
  alias JidoCode.Factory.RepositoryLocator

  @enforce_keys [:responses]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(responses) when is_map(responses), do: {:ok, %__MODULE__{responses: responses}}
  def new(_responses), do: {:error, AdapterError.new(:invalid_input, :fake_provider)}

  @impl true
  def observe_repository(
        %__MODULE__{} = adapter,
        %RepositoryLocator{} = locator,
        %CredentialReference{},
        _options
      ) do
    response(adapter, {:repository, locator.external_id})
  end

  @impl true
  def observe_collection(
        %__MODULE__{} = adapter,
        kind,
        %RepositoryLocator{} = locator,
        %CredentialReference{},
        cursor,
        _options
      ) do
    response(adapter, {kind, locator.external_id, cursor})
  end

  defp response(adapter, key) do
    case Map.get(adapter.responses, key) do
      %{observations: observations, next_cursor: cursor} when is_list(observations) ->
        if Enum.all?(observations, &match?(%ProviderObservation{}, &1)),
          do: {:ok, %{observations: observations, next_cursor: cursor}},
          else: {:error, AdapterError.new(:corrupt, :fake_provider_response)}

      {:error, kind, operation} ->
        {:error, AdapterError.new(kind, operation)}

      nil ->
        {:error, AdapterError.new(:unavailable, :fake_provider_missing_response)}

      _invalid ->
        {:error, AdapterError.new(:corrupt, :fake_provider_response)}
    end
  end
end
