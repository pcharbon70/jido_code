defmodule JidoCode.Install do
  @moduledoc "One-time, fail-closed initialization of ontology and graph authority."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.ReleaseContract

  @spec bootstrap(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def bootstrap(operator_token, options \\ [])

  def bootstrap(operator_token, options) when is_binary(operator_token) and is_list(options) do
    store_server = Keyword.get(options, :store_server, StoreServer)
    writer = Keyword.get(options, :writer, Writer)
    identity = Keyword.get(options, :identity, configured_identity())

    with :ok <- ReleaseContract.verify(),
         true <- byte_size(operator_token) in 24..512,
         %{ready?: true, dataset_revision: 0} <- StoreServer.summary(store_server),
         {:ok, ontology} <- Release.load(store_server: store_server, writer: writer),
         {:ok, command_iri} <- ResourceIdentity.generate_local(:command),
         {:ok, receipt} <-
           Writer.bootstrap(
             writer,
             %{
               command_iri: command_iri,
               factory_iri: identity.factory_iri,
               principal_iri: identity.principal_iri,
               actor_iri: identity.actor_iri,
               factory_scope_iri: identity.factory_scope_iri,
               expected_dataset_revision: ontology.receipt.dataset_revision
             },
             operator_token: operator_token
           ) do
      {:ok,
       %{
         release_contract_digest: ReleaseContract.digest(),
         ontology_version: ontology.version,
         authority_dataset_revision: receipt.dataset_revision,
         factory_iri: receipt.factory_iri,
         actor_iri: receipt.actor_iri,
         graph_iris: receipt.graph_iris
       }}
    else
      %{ready?: false} ->
        {:error, Error.new(:unavailable, :clean_install)}

      %{dataset_revision: revision} when is_integer(revision) and revision > 0 ->
        {:error, Error.new(:conflict, :clean_install_already_initialized)}

      {:error, %Error{} = error} ->
        {:error, error}

      false ->
        {:error, Error.new(:invalid_input, :clean_install_credential)}

      _invalid ->
        {:error, Error.new(:unavailable, :clean_install)}
    end
  end

  def bootstrap(_operator_token, _options),
    do: {:error, Error.new(:invalid_input, :clean_install)}

  defp configured_identity do
    config = Application.fetch_env!(:jido_code, :product_surface)

    %{
      factory_iri: Keyword.fetch!(config, :factory_iri),
      factory_scope_iri: Keyword.fetch!(config, :factory_scope_iri),
      principal_iri: Keyword.fetch!(config, :principal_iri),
      actor_iri: Keyword.fetch!(config, :actor_iri)
    }
  end
end
