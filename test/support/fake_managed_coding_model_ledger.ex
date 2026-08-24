defmodule JidoCode.TestSupport.FakeManagedCodingModelLedger do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ManagedCodingModelLedger

  @impl true
  def start(state, correlation, request) do
    send(state.owner, {:model_ledger_start, correlation, request})
    Map.get(state, :start_result, {:ok, %{invocation_iri: request.invocation_iri}})
  end

  @impl true
  def outcome(state, receipt, attributes) do
    send(state.owner, {:model_ledger_outcome, receipt, attributes})
    Map.get(state, :outcome_result, :ok)
  end
end
