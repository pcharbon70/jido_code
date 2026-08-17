defmodule JidoCode.Factory.Model.RecoveryArbiter do
  @moduledoc "Expected-revision arbiter for one result recovered after an ambiguous model call."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @derive {Inspect, only: [:invocation_iri, :revision, :status]}
  @enforce_keys [:invocation_iri, :revision, :status, :result_digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(String.t(), non_neg_integer()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(invocation_iri, revision) when is_integer(revision) and revision >= 0 do
    with :ok <- Knowledge.validate_resource_identity(invocation_iri) do
      {:ok,
       %__MODULE__{
         invocation_iri: invocation_iri,
         revision: revision,
         status: :ambiguous,
         result_digest: nil
       }}
    else
      _invalid -> invalid()
    end
  end

  def new(_invocation_iri, _revision), do: invalid()

  @spec advance(t(), non_neg_integer(), String.t()) ::
          {:ok, :committed | :idempotent, t()} | {:error, AdapterError.t()}
  def advance(%__MODULE__{} = state, expected_revision, result_digest)
      when is_integer(expected_revision) and is_binary(result_digest) do
    cond do
      not Regex.match?(~r/^sha256:[a-f0-9]{64}$/, result_digest) ->
        invalid()

      state.status == :ambiguous and expected_revision == state.revision ->
        {:ok, :committed,
         %{state | status: :recovered, revision: state.revision + 1, result_digest: result_digest}}

      state.status == :recovered and expected_revision == state.revision - 1 and
          result_digest == state.result_digest ->
        {:ok, :idempotent, state}

      true ->
        {:error, AdapterError.new(:conflict, :model_result_recovery)}
    end
  end

  def advance(_state, _expected_revision, _result_digest), do: invalid()

  @spec ambiguous_outcome(AdapterError.t()) :: map()
  def ambiguous_outcome(%AdapterError{} = error) do
    %{
      status: :ambiguous,
      model_call_ref: nil,
      usage: %{},
      diagnostic: "gateway=ambiguous;error=#{error.kind};operation=#{error.operation}"
    }
  end

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :model_result_recovery)}
end
