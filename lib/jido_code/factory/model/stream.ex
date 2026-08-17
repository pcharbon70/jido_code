defmodule JidoCode.Factory.Model.Stream do
  @moduledoc """
  Opaque handle for a single model response stream.

  Factory code may retain and return this value but must use the selected
  adapter to consume or close the provider-owned handle.
  """

  @derive {Inspect, only: [:invocation_iri]}
  @enforce_keys [:invocation_iri, :handle]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(String.t(), term()) :: t()
  def new(invocation_iri, handle) when is_binary(invocation_iri) do
    %__MODULE__{invocation_iri: invocation_iri, handle: handle}
  end
end
