defmodule JidoCode.TestSupport.FakeTrustedConnector do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.TrustedConnector

  @impl true
  def identity(connector), do: {:ok, connector.identity}

  @impl true
  def execute(connector, permit, {:local_cli_reference, reference_iri}, payload) do
    send(
      connector.owner,
      {:trusted_connector_reference, permit.id, reference_iri, payload[:operation]}
    )

    result(connector)
  end

  def execute(connector, permit, material, payload) when is_binary(material) do
    send(
      connector.owner,
      {:trusted_connector_material, permit.id, byte_size(material), payload[:operation]}
    )

    result(connector)
  end

  defp result(%{result: result}), do: result
  defp result(_connector), do: {:ok, %{status: :completed, provider_ref: "provider-operation-1"}}
end
