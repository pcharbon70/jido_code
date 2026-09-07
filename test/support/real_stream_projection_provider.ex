defmodule JidoCode.TestSupport.RealStreamProjectionProvider do
  @moduledoc false
  @behaviour JidoCode.Product.ReadProjectionProvider
  alias JidoCode.Identity.AuthorityBuilder
  alias JidoCode.Knowledge.{Health, QueryRunner}
  alias JidoCode.Product.GraphReadProjectionProvider

  def load(context, options) do
    fixture = Application.fetch_env!(:jido_code, :hui_d3_graph_fixture)
    # Test-only bridge: current named-human admission and field authorization are
    # real; the independent test dataset is queried as its explicitly granted
    # fixture principal, never by an allow-all QueryRunner or synthetic result.
    authorize = fn context, operation, area, action, point, resource ->
      with {:ok, request} <-
             AuthorityBuilder.request(operation, area, action, resource,
               reauthorization_point: point,
               correlation_ref: "d3-real-store-query"
             ),
           {:ok, %{decision: :allowed} = authorization} <-
             AuthorityBuilder.build(context.session_ref, request, touch: false) do
        {:ok, %{authorization | authority_context: fixture.authority}}
      else
        _ -> {:error, :denied}
      end
    end

    query = fn name, version, parameters, authority, scope, _ ->
      QueryRunner.execute(name, version, parameters, authority, scope,
        server: fixture.query_runner,
        evaluated_at: fixture.issued_at
      )
    end

    GraphReadProjectionProvider.load(
      context,
      Keyword.merge(options,
        authorize: authorize,
        query: query,
        cache_server: nil,
        health: %Health{state: :ready, store_verified?: true, ontology_verified?: true},
        clock: fn -> fixture.issued_at end
      )
    )
  end
end
