defmodule JidoCode.Runtime.ManagedCoding.Directive.Observation do
  @moduledoc "Record one bounded runtime observation through a Factory facade."
  alias JidoCode.Runtime.ManagedCoding.Directive.Envelope
  @enforce_keys [:envelope]
  defstruct @enforce_keys
  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attributes), do: wrap(Envelope.new(:observation, attributes))
  @type t :: %__MODULE__{envelope: Envelope.t()}
  defp wrap({:ok, envelope}), do: {:ok, %__MODULE__{envelope: envelope}}
  defp wrap(error), do: error
end
