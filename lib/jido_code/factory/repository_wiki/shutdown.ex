defmodule JidoCode.Factory.RepositoryWiki.Shutdown do
  @moduledoc "Executes a graph-committed wiki disable before any cancellation side effect."

  alias JidoCode.Knowledge

  @ordered_actions [
    :stop_admission,
    :terminal_pending_triggers,
    :cancel_active_effects,
    :revoke_leases,
    :reconcile_accounting,
    :retain_artifacts,
    :stop_owner
  ]

  @spec execute(map(), map()) :: {:ok, map()} | {:error, map()}
  def execute(plan, ports) when is_map(plan) and is_map(ports) do
    with true <- Knowledge.valid_repository_wiki_cancellation_plan?(plan),
         {:ok, commit_receipt} <- commit(plan, ports) do
      outcomes =
        Enum.map(@ordered_actions, fn name ->
          {name, invoke_action(name, plan.actions[name], plan, ports)}
        end)

      {:ok,
       %{
         state: :disabled,
         commit_receipt: commit_receipt,
         action_outcomes: Map.new(outcomes),
         retained_read: plan.retained_read,
         cancellation_generation: plan.cancellation_generation,
         digest: Knowledge.repository_wiki_digest(outcomes)
       }}
    else
      false -> {:error, %{outcome: :invalid_plan, effect_started?: false}}
      {:error, reason} -> {:error, %{outcome: reason, effect_started?: false}}
    end
  rescue
    _error -> {:error, %{outcome: :invalid_shutdown, effect_started?: false}}
  end

  def execute(_plan, _ports),
    do: {:error, %{outcome: :invalid_shutdown, effect_started?: false}}

  @spec result_current?(map(), map()) :: boolean()
  def result_current?(result, current),
    do: Knowledge.repository_wiki_result_current?(result, current)

  defp commit(plan, ports) do
    case Map.fetch(ports, :commit_disable) do
      {:ok, fun} when is_function(fun, 1) ->
        case fun.(plan.disable_command) do
          {:ok, receipt} -> {:ok, receipt}
          {:duplicate, receipt} -> {:ok, receipt}
          {:error, reason} -> {:error, reason}
          _invalid -> {:error, :invalid_commit_receipt}
        end

      _missing ->
        {:error, :disable_commit_unavailable}
    end
  end

  defp invoke_action(name, action, plan, ports) do
    case Map.fetch(ports, name) do
      {:ok, fun} when is_function(fun, 2) -> normalize(fun.(action, plan))
      _missing -> {:error, :port_unavailable}
    end
  rescue
    _error -> {:error, :port_failure}
  end

  defp normalize(:ok), do: :ok
  defp normalize({:ok, result}), do: {:ok, result}
  defp normalize({:error, reason}), do: {:error, reason}
  defp normalize(_result), do: {:error, :invalid_port_result}
end
