defmodule JidoCode.Factory.Model.Stream do
  @moduledoc """
  Opaque handle for a single model response stream.

  Factory code may retain and return this value but must use the selected
  adapter to consume or close the provider-owned handle.
  """

  @derive {Inspect, only: [:invocation_iri, :adapter_module]}
  @enforce_keys [
    :invocation_iri,
    :handle,
    :adapter_module,
    :adapter,
    :profile,
    :request
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(String.t(), term(), module(), term(), term(), term()) :: t()
  def new(invocation_iri, handle, adapter_module, adapter, profile, request)
      when is_binary(invocation_iri) and is_atom(adapter_module) do
    %__MODULE__{
      invocation_iri: invocation_iri,
      handle: handle,
      adapter_module: adapter_module,
      adapter: adapter,
      profile: profile,
      request: request
    }
  end
end
