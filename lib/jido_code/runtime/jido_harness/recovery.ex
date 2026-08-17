defmodule JidoCode.Runtime.JidoHarness.Recovery do
  @moduledoc "Classifies missing disposable CLI state without inventing a graph state."

  @classes ~w[recover supersede propagated_cancellation abandon retry_later]a

  @spec classify(map()) :: {:ok, atom()} | {:error, :invalid_recovery_context}
  def classify(context) when is_map(context) do
    classification =
      cond do
        context[:terminal_callback_proven] == true -> :recover
        context[:runtime_compatible] == false -> :supersede
        context[:cancellation_committed] == true -> :propagated_cancellation
        context[:lease_state] in [:inactive, :expired, :revoked] -> :abandon
        context[:lease_state] == :active -> :retry_later
        true -> nil
      end

    if classification in @classes,
      do: {:ok, classification},
      else: {:error, :invalid_recovery_context}
  end

  def classify(_context), do: {:error, :invalid_recovery_context}

  @spec classes() :: [atom()]
  def classes, do: @classes
end
