defmodule JidoCode.Factory.ManagedCoding.EffectPolicy do
  @moduledoc "Closed idempotency and reconciliation classification for external operations."

  alias JidoCode.Factory.AdapterError

  @contracts %{
    context_read: :replayable,
    model_generation: :query_reconcilable,
    tool_read: :replayable,
    tool_mutation: :query_reconcilable,
    filesystem_write: :query_reconcilable,
    credential_checkout: :compensatable,
    artifact_put: :query_reconcilable,
    verifier_run: :query_reconcilable,
    interaction_open: :query_reconcilable,
    publication: :manual_resolution_only
  }

  @spec classify(atom()) :: {:ok, atom()} | {:error, AdapterError.t()}
  def classify(operation) when is_map_key(@contracts, operation),
    do: {:ok, Map.fetch!(@contracts, operation)}

  def classify(_operation),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_effect_policy)}

  @spec contracts() :: map()
  def contracts, do: @contracts
end
