defmodule JidoCode.TestSupport.FakeApprovalLedger do
  @moduledoc false

  use GenServer

  @behaviour JidoCode.Factory.Ports.ApprovalLedger

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Approval.Request

  def start_link(options \\ []), do: GenServer.start_link(__MODULE__, %{}, options)

  @impl true
  def consume(server, request, _current, options),
    do: GenServer.call(server, {:consume, request, Keyword.get(options, :owner)})

  @impl true
  def terminal(server, consumption, result, options),
    do: GenServer.call(server, {:terminal, consumption, result, Keyword.get(options, :owner)})

  @impl true
  def ambiguous(server, consumption, observation, options),
    do:
      GenServer.call(server, {:ambiguous, consumption, observation, Keyword.get(options, :owner)})

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:consume, request, owner}, _from, state) do
    approval_iri = Request.approval_iri(request)

    case Map.get(state, approval_iri) do
      nil ->
        receipt = %{
          outcome: :committed,
          status: :consumed,
          approval_iri: approval_iri,
          invocation_iri: request.invocation_iri,
          invocation_recorded?: true,
          approval_consumed?: true,
          atomic?: true,
          terminal_recorded?: false,
          observation_count: 0
        }

        notify(owner, {:approval_ledger, :consumed, approval_iri})
        {:reply, {:ok, receipt}, Map.put(state, approval_iri, receipt)}

      _existing ->
        {:reply, conflict(:approval_already_consumed), state}
    end
  end

  def handle_call({:terminal, consumption, result, owner}, _from, state) do
    approval_iri = consumption.approval_iri

    case Map.get(state, approval_iri) do
      %{terminal_recorded?: false} = current ->
        receipt = %{
          outcome: :committed,
          status: result.status,
          invocation_iri: current.invocation_iri,
          terminal_recorded?: true
        }

        notify(owner, {:approval_ledger, :terminal, current.invocation_iri})
        {:reply, {:ok, receipt}, Map.put(state, approval_iri, Map.merge(current, receipt))}

      _existing ->
        {:reply, conflict(:approval_terminal_exists), state}
    end
  end

  def handle_call({:ambiguous, consumption, _observation, owner}, _from, state) do
    approval_iri = consumption.approval_iri

    case Map.get(state, approval_iri) do
      %{terminal_recorded?: false, observation_count: count} = current when count < 3 ->
        receipt = %{
          outcome: :committed,
          status: :ambiguous,
          invocation_iri: current.invocation_iri,
          terminal_recorded?: false,
          observation_count: count + 1
        }

        notify(owner, {:approval_ledger, :ambiguous, current.invocation_iri, count + 1})
        {:reply, {:ok, receipt}, Map.put(state, approval_iri, Map.merge(current, receipt))}

      _existing ->
        {:reply, conflict(:approval_reconciliation_bound), state}
    end
  end

  defp notify(owner, message) when is_pid(owner), do: send(owner, message)
  defp notify(_owner, _message), do: :ok
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
end
