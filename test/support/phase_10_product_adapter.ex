defmodule JidoCode.TestSupport.Phase10ProductAdapter do
  @moduledoc false

  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.Product.CommandGateway
  alias JidoCode.Product.GraphProjectionProvider

  def load(authority, identity, options) do
    substrate = substrate!()

    query = fn name, version, parameters, query_authority, scope, query_options ->
      QueryRunner.execute(
        name,
        version,
        parameters,
        query_authority,
        scope,
        Keyword.put(query_options, :server, substrate.query_runner)
      )
    end

    GraphProjectionProvider.load(
      authority,
      identity,
      Keyword.merge(options,
        health: Readiness.snapshot(substrate.readiness),
        query: query,
        metadata: fn graph ->
          QueryRunner.graph_metadata(graph, server: substrate.query_runner)
        end
      )
    )
  end

  def enroll_repository(authority, identity, params) do
    substrate = substrate!()

    CommandGateway.enroll_repository(authority, identity, params,
      clock: fn -> substrate.issued_at end,
      summary: fn -> StoreServer.summary(substrate.store_server) end,
      metadata: fn graph ->
        QueryRunner.graph_metadata(graph, server: substrate.query_runner)
      end,
      execute: fn command -> Writer.execute(substrate.writer, command) end
    )
  end

  defp substrate! do
    Application.fetch_env!(:jido_code, :phase_10_product_substrate)
  end
end
