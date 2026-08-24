defmodule JidoCode.Runtime.ManagedCodingDispatcherTest do
  use ExUnit.Case, async: false

  alias JidoCode.Runtime.ManagedCoding.Directive.Actor
  alias JidoCode.Runtime.ManagedCoding.Directive.Candidate
  alias JidoCode.Runtime.ManagedCoding.Directive.Context
  alias JidoCode.Runtime.ManagedCoding.Directive.Continuation
  alias JidoCode.Runtime.ManagedCoding.Directive.Model
  alias JidoCode.Runtime.ManagedCoding.Directive.Observation
  alias JidoCode.Runtime.ManagedCoding.Directive.Tool
  alias JidoCode.Runtime.ManagedCoding.Dispatcher
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeManagedCodingDirective

  test "constructs all seven closed directive types and rejects implementation smuggling" do
    modules = [Context, Model, Tool, Actor, Candidate, Observation, Continuation]

    for module <- modules do
      assert {:ok, directive} = module.new(attributes(%{purpose: :bounded_test}))
      assert directive.envelope.payload_digest =~ ~r/^[a-f0-9]{64}$/

      assert directive.envelope.kind in ~w[context model tool actor candidate observation continuation]a
    end

    for payload <- [
          %{module: "Danger"},
          %{nested: %{adapter: "raw"}},
          %{callback: fn -> :effect end}
        ] do
      assert {:error, %{kind: :invalid_input}} = Context.new(attributes(payload))
    end
  end

  test "fails closed when any host handler is missing" do
    owner = self()
    previous = Process.flag(:trap_exit, true)
    on_exit(fn -> Process.flag(:trap_exit, previous) end)

    assert {:error, %JidoCode.Factory.AdapterError{operation: :managed_coding_dispatcher}} =
             Dispatcher.start_link(
               handlers: Map.delete(handlers(%{owner: owner}), :tool),
               current_provider: fn _attempt -> %{} end,
               delivery: fn _target, _signal -> :ok end
             )
  end

  test "queues per attempt, applies back-pressure, and correlates successful delivery" do
    current = start_current!(:queue_current)

    handlers =
      handlers(%{
        owner: self(),
        mode: :wait,
        result: %{
          context_digest: digest("context"),
          model_invocation_iri: resource(:model_invocation, "next")
        }
      })

    dispatcher = start_dispatcher!(current, handlers, max_queue: 1)

    {:ok, first} = Context.new(attributes(%{request: "first"}, 1))
    {:ok, second} = Context.new(attributes(%{request: "second"}, 2))
    {:ok, third} = Context.new(attributes(%{request: "third"}, 3))

    assert :ok = Dispatcher.dispatch(dispatcher, first, self())
    assert_receive {:directive_effect, first_task, %{sequence: 1}}
    assert :ok = Dispatcher.dispatch(dispatcher, second, self())

    assert {:error, %{operation: :managed_coding_backpressure}} =
             Dispatcher.dispatch(dispatcher, third, self())

    assert Dispatcher.status(dispatcher) == %{
             active: 1,
             queued: 1,
             active_by_attempt: %{attempt() => 1}
           }

    send(first_task, :release)

    assert_receive {:delivered,
                    %Jido.Signal{
                      type: "jido_code.managed_coding.context_result",
                      data: first_data
                    }}

    assert first_data.sequence == 1
    assert first_data.attempt_iri == attempt()
    assert first_data.effect_type == :context
    refute Map.has_key?(first_data, :module)

    assert_receive {:directive_effect, second_task, %{sequence: 2}}
    send(second_task, :release)
    assert_receive {:delivered, %Jido.Signal{data: %{sequence: 2}}}
    assert Dispatcher.status(dispatcher).active == 0
  end

  test "bounds crashes, corrupt returns, adapter errors, timeouts, and cancellation" do
    for {mode, expected} <- [
          {:crash, :crash},
          {:corrupt, :corrupt},
          {:error, :unavailable}
        ] do
      current = start_current!({:failure_current, mode})
      dispatcher = start_dispatcher!(current, handlers(%{owner: self(), mode: mode}), id: mode)
      {:ok, directive} = Model.new(attributes(%{request: mode}))
      assert :ok = Dispatcher.dispatch(dispatcher, directive, self())
      assert_receive {:directive_effect, _pid, _envelope}

      assert_receive {:delivered,
                      %Jido.Signal{data: %{outcome: :failed, error: ^expected, kind: :failure}}}

      refute_received {:delivered, %Jido.Signal{data: %{error: "private backend crash"}}}
    end

    current = start_current!(:timeout_current)

    dispatcher =
      start_dispatcher!(current, handlers(%{owner: self(), mode: :wait}), id: :timeout_dispatcher)

    {:ok, timed} = Tool.new(attributes(%{request: :timeout}, 1, 30))
    assert :ok = Dispatcher.dispatch(dispatcher, timed, self())
    assert_receive {:directive_effect, _pid, _envelope}
    assert_receive {:delivered, %Jido.Signal{data: %{error: :timeout, kind: :failed}}}, 500

    current = start_current!(:cancel_current)

    dispatcher =
      start_dispatcher!(current, handlers(%{owner: self(), mode: :wait}), id: :cancel_dispatcher)

    {:ok, cancelled} = Candidate.new(attributes(%{request: :cancel}))
    assert :ok = Dispatcher.dispatch(dispatcher, cancelled, self())
    assert_receive {:directive_effect, _pid, _envelope}
    assert :ok = Dispatcher.cancel(dispatcher, attempt(), 7)
    assert_receive {:delivered, %Jido.Signal{data: %{error: :cancelled}}}
    assert Dispatcher.status(dispatcher).active == 0
  end

  test "drops late results when the current runtime identity changes" do
    current = start_current!(:late_current)
    dispatcher = start_dispatcher!(current, handlers(%{owner: self(), mode: :wait}))
    {:ok, directive} = Observation.new(attributes(%{request: :late}))
    assert :ok = Dispatcher.dispatch(dispatcher, directive, self())
    assert_receive {:directive_effect, task, _envelope}

    Agent.update(current, fn _value -> %{target: self(), current?: false} end)
    send(task, :release)
    refute_receive {:delivered, _signal}, 100
    assert Dispatcher.status(dispatcher).active == 0
  end

  defp start_dispatcher!(current, handlers, options \\ []) do
    owner = self()

    child =
      Supervisor.child_spec(
        {Dispatcher,
         [
           handlers: handlers,
           current_provider: fn requested_attempt ->
             value = Agent.get(current, & &1)

             Map.merge(value, %{
               attempt_iri: requested_attempt,
               fencing_token: 7
             })
           end,
           delivery: fn _target, signal -> send(owner, {:delivered, signal}) end,
           max_concurrency: 2,
           max_per_attempt: 1,
           max_queue: Keyword.get(options, :max_queue, 8)
         ]},
        id: Keyword.get(options, :id, Dispatcher)
      )

    start_supervised!(child)
  end

  defp start_current!(id) do
    owner = self()
    child = Supervisor.child_spec({Agent, fn -> %{target: owner, current?: true} end}, id: id)
    start_supervised!(child)
  end

  defp handlers(state) do
    Map.new(
      ~w[context model tool actor candidate observation continuation]a,
      &{&1, {FakeManagedCodingDirective, state}}
    )
  end

  defp attributes(payload, sequence \\ 1, timeout_ms \\ 1_000) do
    %{
      attempt_iri: attempt(),
      fencing_token: 7,
      sequence: sequence,
      invocation_iri: resource(:tool_invocation, "directive-#{sequence}-#{inspect(payload)}"),
      deadline: DateTime.add(DateTime.utc_now(), timeout_ms, :millisecond),
      payload: payload
    }
  end

  defp attempt, do: resource(:execution_attempt, "dispatcher-attempt")

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
