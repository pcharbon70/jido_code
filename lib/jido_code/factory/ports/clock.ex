defmodule JidoCode.Factory.Ports.Clock do
  @moduledoc "Injectable trusted time port for observation retrieval."

  @callback now(clock :: term()) :: DateTime.t()
end
