defmodule JidoCode.Knowledge.CommandReceipt do
  @moduledoc """
  Bounded public outcome for a semantic command.

  Failure receipts expose stable issue codes and revision guidance only when
  the caller is authorized. Unauthorized outcomes deliberately conceal
  resource existence and policy details.
  """

  @outcomes [
    :committed,
    :already_committed,
    :rejected,
    :conflicted,
    :unauthorized,
    :invalid,
    :unavailable,
    :unknown_after_timeout
  ]
  @failure_outcomes @outcomes -- [:committed, :already_committed]
  @max_issues 20

  @enforce_keys [:outcome, :retry]
  defstruct [
    :outcome,
    :retry,
    :command_iri,
    :change_set_iri,
    :dataset_revision,
    :graph_revisions,
    :affected_graphs,
    :assertion_count,
    :supersession_count,
    :actor_iri,
    :committed_at,
    :current_revisions,
    :failed_precondition,
    issues: []
  ]

  @type outcome ::
          :committed
          | :already_committed
          | :rejected
          | :conflicted
          | :unauthorized
          | :invalid
          | :unavailable
          | :unknown_after_timeout

  @type t :: %__MODULE__{}

  @spec success(outcome(), map()) :: t()
  def success(outcome, attributes) when outcome in [:committed, :already_committed] do
    struct!(__MODULE__,
      outcome: outcome,
      retry: :never,
      command_iri: attributes.command_iri,
      change_set_iri: attributes.change_set_iri,
      dataset_revision: attributes.dataset_revision,
      graph_revisions: attributes.graph_revisions,
      affected_graphs: attributes.affected_graphs |> Enum.uniq() |> Enum.sort(),
      assertion_count: attributes.assertion_count,
      supersession_count: attributes.supersession_count,
      actor_iri: attributes.actor_iri,
      committed_at: attributes.committed_at
    )
  end

  @spec failure(outcome(), keyword()) :: t()
  def failure(outcome, options \\ []) when outcome in @failure_outcomes do
    if outcome == :unauthorized do
      %__MODULE__{outcome: :unauthorized, retry: :never}
    else
      %__MODULE__{
        outcome: outcome,
        retry: Keyword.get(options, :retry, retry(outcome)),
        command_iri: Keyword.get(options, :command_iri),
        current_revisions: Keyword.get(options, :current_revisions),
        failed_precondition: Keyword.get(options, :failed_precondition),
        issues: options |> Keyword.get(:issues, []) |> safe_issues()
      }
    end
  end

  @spec outcomes() :: [outcome()]
  def outcomes, do: @outcomes

  defp retry(:conflicted), do: :refresh
  defp retry(:unavailable), do: :retry
  defp retry(:unknown_after_timeout), do: :verify_receipt
  defp retry(_outcome), do: :never

  defp safe_issues(issues) when is_list(issues) do
    issues
    |> Enum.filter(
      &(is_binary(&1) and byte_size(&1) <= 80 and Regex.match?(~r/^[a-z0-9_]+$/, &1))
    )
    |> Enum.uniq()
    |> Enum.take(@max_issues)
  end

  defp safe_issues(_issues), do: []
end
