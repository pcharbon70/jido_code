defmodule JidoCode.Runtime.ManagedCoding.Directive.Continuation do
  @moduledoc "Request one host-authorized bounded continuation decision."
  alias JidoCode.Runtime.ManagedCoding.Directive.Envelope
  @enforce_keys [:envelope]
  defstruct @enforce_keys
  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attributes), do: wrap(Envelope.new(:continuation, attributes))
  @type t :: %__MODULE__{envelope: Envelope.t()}
  defp wrap({:ok, envelope}), do: {:ok, %__MODULE__{envelope: envelope}}
  defp wrap(error), do: error
end
