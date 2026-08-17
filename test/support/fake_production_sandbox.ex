defmodule JidoCode.TestSupport.FakeProductionSandbox do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ProductionSandbox
  @behaviour JidoCode.Factory.Ports.Sandbox

  alias JidoCode.Factory.Sandbox.Event

  @impl true
  def isolation_profile(%{profile: profile}), do: {:ok, profile}

  @impl true
  def provision(adapter, request, options),
    do: event(adapter, request, :provision, %{status: :ready}, options)

  @impl true
  def materialize(adapter, request, snapshot, options),
    do:
      event(
        adapter,
        request,
        :materialize,
        %{status: :materialized, snapshot_iri: snapshot[:snapshot_iri]},
        options
      )

  @impl true
  def execute(adapter, request, command, options),
    do:
      event(
        adapter,
        request,
        :execute,
        %{status: :completed, command: command[:name], usage: command[:usage] || %{}},
        options
      )

  @impl true
  def inspect(adapter, request, options),
    do: event(adapter, request, :inspect, %{status: :ready}, options)

  @impl true
  def cancel(adapter, request, options),
    do: event(adapter, request, :cancel, %{status: :cancelled}, options)

  @impl true
  def collect(adapter, request, options),
    do: event(adapter, request, :collect, %{status: :captured, byte_count: 128}, options)

  @impl true
  def destroy(adapter, request, options),
    do: event(adapter, request, :destroy, %{status: :destroyed}, options)

  defp event(adapter, request, operation, details, options) do
    send(adapter.owner, {:production_sandbox, operation, request.execution.attempt_iri})
    profile = Keyword.fetch!(options, :isolation_profile)

    Event.new(%{
      attempt_iri: request.execution.attempt_iri,
      operation: operation,
      outcome: if(operation == :cancel, do: :cancelled, else: :success),
      occurred_at: adapter.clock.(),
      provider_ref: JidoCode.Factory.Execution.Request.runtime_key(request.execution),
      details:
        Map.merge(details, %{
          isolation_tier: profile.tier,
          image_digest: profile.image_digest
        })
    })
  end
end
