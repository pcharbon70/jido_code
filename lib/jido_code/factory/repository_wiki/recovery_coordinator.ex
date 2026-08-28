defmodule JidoCode.Factory.RepositoryWiki.RecoveryCoordinator do
  @moduledoc "Bounded parallel startup recovery rebuilt from current repository-wiki graph facts."

  use GenServer

  alias JidoCode.Knowledge

  @maximum_enrollments 200
  @maximum_concurrency 8

  def start_link(options \\ []) do
    name = Keyword.get(options, :name, __MODULE__)

    if is_nil(name),
      do: GenServer.start_link(__MODULE__, options),
      else: GenServer.start_link(__MODULE__, options, name: name)
  end

  def scan(server \\ __MODULE__), do: GenServer.call(server, :scan, :infinity)
  def status(server \\ __MODULE__), do: GenServer.call(server, :status)

  @impl true
  def init(options) do
    {:ok,
     %{
       enrollment_loader: Keyword.get(options, :enrollment_loader, &empty_enrollments/0),
       fact_loader: Keyword.get(options, :fact_loader, &unavailable_facts/1),
       ports: Keyword.get(options, :ports, %{}),
       clock: Keyword.get(options, :clock, &DateTime.utc_now/0),
       maximum_enrollments: Keyword.get(options, :maximum_enrollments, @maximum_enrollments),
       maximum_concurrency: Keyword.get(options, :maximum_concurrency, @maximum_concurrency),
       scan_count: 0,
       status: :starting,
       results: []
     }, {:continue, :startup_scan}}
  end

  @impl true
  def handle_continue(:startup_scan, state), do: {:noreply, run_scan(state)}

  @impl true
  def handle_call(:scan, _from, state) do
    next = run_scan(state)
    {:reply, {:ok, next.results}, next}
  end

  def handle_call(:status, _from, state) do
    {:reply,
     %{
       status: state.status,
       scan_count: state.scan_count,
       repository_count: length(state.results),
       results: state.results
     }, state}
  end

  defp run_scan(state) do
    case state.enrollment_loader.() do
      {:ok, enrollments}
      when is_list(enrollments) and length(enrollments) <= state.maximum_enrollments ->
        results =
          enrollments
          |> Task.async_stream(&recover(&1, state),
            max_concurrency: state.maximum_concurrency,
            ordered: false,
            timeout: :infinity
          )
          |> Enum.map(&task_result/1)
          |> Enum.sort_by(&{&1[:tenant_iri] || "", &1[:repository_iri] || ""})

        %{
          state
          | status: aggregate_status(results),
            results: results,
            scan_count: state.scan_count + 1
        }

      {:ok, _too_many_or_invalid} ->
        global_failure(state, :enrollment_scan_out_of_bounds)

      {:error, reason} ->
        global_failure(state, {:store_unavailable, reason})

      _invalid ->
        global_failure(state, :invalid_enrollment_scan)
    end
  rescue
    _error -> global_failure(state, :enrollment_scan_failed)
  end

  defp recover(enrollment, state) do
    repository_iri = enrollment[:repository_iri]
    tenant_iri = enrollment[:tenant_iri]

    result =
      with {:ok, facts} <- state.fact_loader.(enrollment),
           {:ok, plan} <-
             Knowledge.plan_repository_wiki_maintainer_recovery(
               enrollment,
               facts,
               DateTime.truncate(state.clock.(), :microsecond)
             ) do
        execute_plan(plan, state.ports)
      else
        {:error, reason} -> %{status: :degraded, reason: reason, actions: []}
        _invalid -> %{status: :degraded, reason: :invalid_recovery_input, actions: []}
      end

    Map.merge(result, %{repository_iri: repository_iri, tenant_iri: tenant_iri})
  rescue
    _error ->
      %{
        repository_iri: if(is_map(enrollment), do: enrollment[:repository_iri], else: nil),
        tenant_iri: if(is_map(enrollment), do: enrollment[:tenant_iri], else: nil),
        status: :degraded,
        reason: :recovery_failed,
        actions: []
      }
  end

  defp execute_plan(%{status: status} = plan, _ports)
       when status in [:ineligible, :degraded, :owned] do
    %{
      status: status,
      degraded_dependencies: plan.degraded_dependencies,
      actions: [],
      superseded: plan.superseded,
      plan_digest: plan.digest
    }
  end

  defp execute_plan(plan, ports) do
    {status, outcomes} =
      Enum.reduce_while(plan.actions, {:recovered, []}, fn action, {_status, outcomes} ->
        outcome = execute_action(action, plan, ports)

        case outcome do
          {:ok, value} -> {:cont, {:recovered, [{action.action, value} | outcomes]}}
          :ok -> {:cont, {:recovered, [{action.action, :ok} | outcomes]}}
          {:error, reason} -> {:halt, {:degraded, [{action.action, {:error, reason}} | outcomes]}}
        end
      end)

    %{
      status: status,
      degraded_dependencies: if(status == :degraded, do: [:recovery_port], else: []),
      actions: Enum.reverse(outcomes),
      superseded: plan.superseded,
      plan_digest: plan.digest
    }
  end

  defp execute_action(action, plan, ports) do
    case Map.fetch(ports, action.action) do
      {:ok, fun} when is_function(fun, 2) -> normalize(fun.(action, plan))
      _missing -> {:error, :port_unavailable}
    end
  rescue
    _error -> {:error, :port_failure}
  end

  defp task_result({:ok, result}), do: result
  defp task_result({:exit, reason}), do: %{status: :degraded, reason: {:task_exit, reason}}

  defp aggregate_status(results) do
    if Enum.any?(results, &(&1.status == :degraded)), do: :degraded, else: :ready
  end

  defp global_failure(state, reason) do
    result = %{status: :degraded, reason: reason, repository_iri: nil, tenant_iri: nil}
    %{state | status: :degraded, results: [result], scan_count: state.scan_count + 1}
  end

  defp normalize(:ok), do: :ok
  defp normalize({:ok, value}), do: {:ok, value}
  defp normalize({:error, reason}), do: {:error, reason}
  defp normalize(_invalid), do: {:error, :invalid_port_result}

  defp empty_enrollments, do: {:ok, []}
  defp unavailable_facts(_enrollment), do: {:error, :fact_loader_unavailable}
end
