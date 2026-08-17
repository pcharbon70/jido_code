defmodule JidoCode.TestSupport.FakeToolLedger do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ToolLedger

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.StartReceipt

  @impl true
  def start(ledger, authorization, request) do
    send(ledger.owner, {:tool_ledger_start, authorization, request})

    case Map.get(ledger, :start_result, :committed) do
      outcome when outcome in [:committed, :idempotent] ->
        StartReceipt.new(%{
          invocation_iri: request.invocation_iri,
          authorization_digest: authorization.decision_digest,
          outcome: outcome,
          opaque: :fake
        })

      {:error, %AdapterError{} = error} ->
        {:error, error}
    end
  end

  @impl true
  def outcome(ledger, start_receipt, result) do
    send(ledger.owner, {:tool_ledger_outcome, start_receipt, result})

    case Map.get(ledger, :outcome_result, :committed) do
      outcome when outcome in [:committed, :idempotent] -> {:ok, %{outcome: outcome}}
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  end
end
