defmodule JidoCode.Product.WorkflowOutcome do
  @moduledoc "Bounded product outcome shared by browser, JSON, and CLI coding-agent surfaces."

  @codes ~w[admitted duplicate stale unauthorized incompatible unavailable rejected conflict]a
  @retries ~w[never refresh retry]a

  @enforce_keys [:code, :retry]
  defstruct @enforce_keys ++ [:attempt_ref, :state]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attributes) when is_map(attributes) do
    with code when code in @codes <- attributes[:code],
         retry when retry in @retries <- attributes[:retry],
         :ok <- optional_ref(attributes[:attempt_ref]),
         :ok <- optional_state(attributes[:state]) do
      {:ok,
       struct!(__MODULE__,
         code: code,
         retry: retry,
         attempt_ref: attributes[:attempt_ref],
         state: attributes[:state]
       )}
    else
      _invalid -> {:error, :invalid_workflow_outcome}
    end
  end

  def new(_attributes), do: {:error, :invalid_workflow_outcome}

  @spec safe_map(t()) :: map()
  def safe_map(%__MODULE__{} = outcome) do
    outcome
    |> Map.from_struct()
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp optional_ref(nil), do: :ok

  defp optional_ref(value) when is_binary(value) and byte_size(value) in 16..96 do
    if Regex.match?(~r/^[A-Za-z0-9_-]+$/, value), do: :ok, else: :error
  end

  defp optional_ref(_value), do: :error
  defp optional_state(nil), do: :ok
  defp optional_state(value) when is_atom(value), do: :ok
  defp optional_state(_value), do: :error
end
