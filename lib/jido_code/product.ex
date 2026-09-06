defmodule JidoCode.Product do
  @moduledoc """
  Product application boundary over graph projections and semantic commands.

  Web modules consume this boundary and never call the knowledge substrate
  directly.
  """

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.GraphReadProjectionProvider
  alias JidoCode.Product.ReadProjection

  @spec subscribe_changes(String.t()) :: :ok | {:error, term()}
  def subscribe_changes(scope_iri), do: Knowledge.subscribe_changes(scope_iri)

  @spec authority(map()) :: {:ok, AuthorityContext.t()} | {:error, term()}
  def authority(identity) when is_map(identity) do
    AuthorityContext.new(%{
      principal_iri: identity.principal_iri,
      actor_iri: identity.actor_iri,
      delegated_agent_iri: nil,
      delegation_iri: nil
    })
  end

  def authority(_identity), do: {:error, :invalid_identity}

  @doc "Loads one bounded, authorized native-shell read projection."
  @spec read_projection(map(), keyword()) :: {:ok, ReadProjection.t()} | {:error, term()}
  def read_projection(context, options \\ [])

  def read_projection(context, options) when is_map(context) and is_list(options) do
    provider =
      Keyword.get(
        options,
        :provider,
        Application.get_env(
          :jido_code,
          :product_read_projection_provider,
          GraphReadProjectionProvider
        )
      )

    case provider.load(context, Keyword.delete(options, :provider)) do
      {:ok, %ReadProjection{} = projection} -> {:ok, projection}
      {:error, reason} -> {:error, reason}
      _invalid -> {:error, :invalid_read_projection_provider}
    end
  rescue
    _error -> {:error, :read_projection_unavailable}
  catch
    :exit, _reason -> {:error, :read_projection_unavailable}
  end

  def read_projection(_context, _options), do: {:error, :invalid_read_projection_context}
end
