defmodule JidoCode.Runtime.ManagedCoding.Directive.Candidate do
  @moduledoc "Capture one immutable local candidate artifact."
  alias JidoCode.Runtime.ManagedCoding.Directive.Envelope
  @enforce_keys [:envelope]
  defstruct @enforce_keys
  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attributes), do: wrap(Envelope.new(:candidate, attributes))
  @type t :: %__MODULE__{envelope: Envelope.t()}
  defp wrap({:ok, envelope}), do: {:ok, %__MODULE__{envelope: envelope}}
  defp wrap(error), do: error
end
