defmodule JidoCode.Knowledge.Error do
  @moduledoc """
  Stable, redacted failures at the public knowledge boundary.

  Backend terms, paths, queries, graph contents, and credentials must not be
  stored in this exception. Detailed causes belong in bounded internal logs.
  """

  @kinds [
    :unavailable,
    :incompatible,
    :locked,
    :corrupt,
    :invalid_input,
    :unauthorized,
    :conflict,
    :stale_precondition,
    :timeout,
    :persistence_failure
  ]

  @retry_modes %{
    unavailable: :retry,
    incompatible: :never,
    locked: :retry,
    corrupt: :never,
    invalid_input: :never,
    unauthorized: :never,
    conflict: :refresh,
    stale_precondition: :refresh,
    timeout: :verify_receipt,
    persistence_failure: :verify_receipt
  }

  @messages %{
    unavailable: "knowledge substrate is unavailable",
    incompatible: "knowledge substrate is incompatible",
    locked: "knowledge substrate is locked",
    corrupt: "knowledge substrate failed integrity verification",
    invalid_input: "knowledge operation input is invalid",
    unauthorized: "knowledge operation is not authorized",
    conflict: "knowledge operation conflicts with current state",
    stale_precondition: "knowledge operation precondition is stale",
    timeout: "knowledge operation timed out",
    persistence_failure: "knowledge operation could not be persisted"
  }

  defexception [:kind, :operation, :retry, :message]

  @type kind ::
          :unavailable
          | :incompatible
          | :locked
          | :corrupt
          | :invalid_input
          | :unauthorized
          | :conflict
          | :stale_precondition
          | :timeout
          | :persistence_failure

  @type retry_mode :: :retry | :verify_receipt | :refresh | :never

  @type t :: %__MODULE__{
          kind: kind(),
          operation: atom(),
          retry: retry_mode(),
          message: String.t()
        }

  def new(kind, operation) when kind in @kinds and is_atom(operation) do
    %__MODULE__{
      kind: kind,
      operation: operation,
      retry: Map.fetch!(@retry_modes, kind),
      message: Map.fetch!(@messages, kind)
    }
  end

  def new(kind, _operation) when kind not in @kinds do
    raise ArgumentError, "unknown knowledge error kind: #{inspect(kind)}"
  end

  def new(_kind, operation) do
    raise ArgumentError, "knowledge error operation must be an atom, got: #{inspect(operation)}"
  end

  def kinds, do: @kinds

  def public(%__MODULE__{} = error) do
    %{kind: error.kind, operation: error.operation, retry: error.retry, message: error.message}
  end
end
