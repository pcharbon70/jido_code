defmodule JidoCode.Factory.Evaluation.Rollout.Stage do
  @moduledoc "Closed Phase 7 rollout ladder and cumulative authority limits."

  @stages %{
    0 => %{name: :contract, actions: [:contract_validation]},
    1 => %{name: :offline, actions: [:contract_validation, :offline_evaluation]},
    2 => %{
      name: :shadow,
      actions: [:contract_validation, :offline_evaluation, :shadow_execution]
    },
    3 => %{
      name: :draft_pr,
      actions: [
        :contract_validation,
        :offline_evaluation,
        :shadow_execution,
        :draft_pull_request
      ]
    },
    4 => %{
      name: :pr_publication,
      actions: [
        :contract_validation,
        :offline_evaluation,
        :shadow_execution,
        :draft_pull_request,
        :pull_request_publication
      ]
    },
    5 => %{
      name: :broader_pr,
      actions: [
        :contract_validation,
        :offline_evaluation,
        :shadow_execution,
        :draft_pull_request,
        :pull_request_publication,
        :broader_pull_request_publication
      ]
    },
    6 => %{
      name: :limited_merge,
      actions: [
        :contract_validation,
        :offline_evaluation,
        :shadow_execution,
        :draft_pull_request,
        :pull_request_publication,
        :broader_pull_request_publication,
        :limited_merge
      ]
    }
  }

  @type t :: 0..6

  @spec all() :: [map()]
  def all do
    @stages
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {id, stage} -> Map.put(stage, :id, id) end)
  end

  @spec fetch(term()) :: {:ok, map()} | :error
  def fetch(id) when is_integer(id), do: Map.fetch(@stages, id)
  def fetch(_id), do: :error

  @spec actions(t()) :: [atom()]
  def actions(id) do
    case fetch(id) do
      {:ok, stage} -> stage.actions
      :error -> []
    end
  end

  @spec next?(term(), term()) :: boolean()
  def next?(current, requested), do: current in 0..5 and requested == current + 1
end
