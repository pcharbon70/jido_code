defmodule JidoCode.Factory.ManagedCoding.Identity do
  @moduledoc "Factory-owned validation boundary for managed coding resource references."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @spec validate_resource(term()) :: :ok | {:error, AdapterError.t()}
  def validate_resource(value) do
    case Knowledge.validate_resource_identity(value) do
      :ok -> :ok
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_resource_identity)}
    end
  end
end
