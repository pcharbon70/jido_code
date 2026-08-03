defmodule JidoCode.Factory.AdapterError do
  @moduledoc "Stable, redacted failure returned by an external adapter."

  @kinds [
    :unavailable,
    :invalid_input,
    :unauthorized,
    :conflict,
    :corrupt,
    :timeout
  ]
  @retry %{
    unavailable: :retry,
    invalid_input: :never,
    unauthorized: :never,
    conflict: :refresh,
    corrupt: :never,
    timeout: :retry
  }

  defexception [:kind, :operation, :retry, message: "external adapter operation failed"]

  @type t :: %__MODULE__{}

  @spec new(atom(), atom()) :: t()
  def new(kind, operation) when kind in @kinds and is_atom(operation) do
    %__MODULE__{kind: kind, operation: operation, retry: Map.fetch!(@retry, kind)}
  end
end
