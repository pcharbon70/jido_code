defmodule JidoCode.Runtime.AttemptWorker do
  @moduledoc false

  use GenServer, restart: :transient

  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.ExecutionRuntime
  alias JidoCode.Runtime.AttemptRegistry

  @spec start_link({Request.t(), keyword()}) :: GenServer.on_start()
  def start_link({%Request{} = request, options}) do
    GenServer.start_link(__MODULE__, {request, options}, name: AttemptRegistry.via(request))
  end

  @spec operation(pid(), atom(), term()) :: term()
  def operation(pid, operation, argument \\ nil),
    do: GenServer.call(pid, {:operation, operation, argument})

  @impl true
  def init({request, options}) do
    {:ok,
     %{
       request: request,
       adapter: Keyword.fetch!(options, :adapter),
       runtime_options: Keyword.get(options, :runtime_options, [])
     }}
  end

  @impl true
  def handle_call({:operation, operation, argument}, _from, state) do
    result = invoke(operation, state.adapter, state.request, argument, state.runtime_options)
    {:reply, result, state}
  end

  defp invoke(:prepare, adapter, request, _argument, options),
    do: ExecutionRuntime.prepare(adapter, request, options)

  defp invoke(:start, adapter, request, _argument, options),
    do: ExecutionRuntime.start(adapter, request, options)

  defp invoke(:status, adapter, request, _argument, options),
    do: ExecutionRuntime.status(adapter, request, options)

  defp invoke(:signal, adapter, request, argument, options),
    do: ExecutionRuntime.signal(adapter, request, argument, options)

  defp invoke(:cancel, adapter, request, argument, options),
    do: ExecutionRuntime.cancel(adapter, request, argument, options)

  defp invoke(:terminate, adapter, request, argument, options),
    do: ExecutionRuntime.terminate(adapter, request, argument, options)
end
