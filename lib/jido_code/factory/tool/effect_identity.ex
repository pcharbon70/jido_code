defmodule JidoCode.Factory.Tool.EffectIdentity do
  @moduledoc "Deterministic identity for one fenced, attempt-scoped external effect."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Knowledge

  @derive {Inspect, only: [:value, :operation, :sequence, :prior_effect_id]}
  @enforce_keys [
    :value,
    :attempt_iri,
    :snapshot_iri,
    :fencing_token,
    :operation,
    :sequence,
    :prior_effect_id
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Request.t(), String.t(), non_neg_integer(), keyword()) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def new(execution, operation, sequence, options \\ [])

  def new(%Request{} = execution, operation, sequence, options)
      when is_binary(operation) and is_integer(sequence) and sequence >= 0 and is_list(options) do
    prior_effect_id = Keyword.get(options, :prior_effect_id)

    with :ok <- Knowledge.validate_resource_identity(execution.attempt_iri),
         :ok <- Knowledge.validate_resource_identity(execution.snapshot_iri),
         true <- byte_size(operation) in 1..256,
         false <- Regex.match?(~r/[\x00-\x1F\x7F]/u, operation),
         :ok <- optional_digest(prior_effect_id) do
      material =
        Enum.join(
          [
            execution.attempt_iri,
            execution.snapshot_iri,
            Integer.to_string(execution.fencing_token),
            operation,
            Integer.to_string(sequence)
          ],
          "\n"
        )

      {:ok,
       %__MODULE__{
         value: "sha256:" <> Base.encode16(:crypto.hash(:sha256, material), case: :lower),
         attempt_iri: execution.attempt_iri,
         snapshot_iri: execution.snapshot_iri,
         fencing_token: execution.fencing_token,
         operation: operation,
         sequence: sequence,
         prior_effect_id: prior_effect_id
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_execution, _operation, _sequence, _options), do: invalid()

  @spec linked_retry(t(), Request.t()) :: {:ok, t()} | {:error, AdapterError.t()}
  def linked_retry(%__MODULE__{} = prior, %Request{} = next_execution) do
    if next_execution.attempt_iri != prior.attempt_iri do
      new(next_execution, prior.operation, prior.sequence, prior_effect_id: prior.value)
    else
      {:error, AdapterError.new(:conflict, :semantic_effect_retry)}
    end
  end

  def linked_retry(_prior, _next_execution), do: invalid()

  defp optional_digest(nil), do: :ok

  defp optional_digest(value) when is_binary(value) do
    if Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value), do: :ok, else: :error
  end

  defp optional_digest(_value), do: :error
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :effect_identity)}
end
