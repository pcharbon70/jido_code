defmodule JidoCode.TestSupport.UnavailableNative do
  @moduledoc false

  alias JidoCode.Knowledge.Error

  def verify, do: {:error, Error.new(:unavailable, :load_native_backend)}
end
