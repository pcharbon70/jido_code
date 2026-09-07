defmodule JidoCode.Product.StreamConvergence do
  @moduledoc "Fixed-cardinality convergence observations; no identifiers or query values."
  @outcomes ~w[hint gap reconcile refreshed stale_revision graph_lag query_unavailable subscription_lost recovery_exhausted revoked]a
  @surfaces ~w[factory fleet projects project project_attempts project_wiki project_dependencies attempt account sessions]a
  def emit(outcome, surface, duration_ms \\ 0)

  def emit(outcome, surface, duration_ms)
      when outcome in @outcomes and surface in @surfaces and is_integer(duration_ms) do
    :telemetry.execute(
      [:jido_code, :product_stream, :convergence],
      %{count: 1, duration_ms: min(max(duration_ms, 0), 60_000)},
      %{outcome: outcome, projection: surface}
    )
  end

  def emit(_, _, _), do: :ok
end
