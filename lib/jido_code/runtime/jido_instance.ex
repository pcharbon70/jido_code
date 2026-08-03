defmodule JidoCode.Runtime.JidoInstance do
  @moduledoc """
  Ephemeral Jido runtime instance.

  Its ETS runtime store is a process-local cache only. The application never
  invokes Jido hibernation/thaw APIs and rebuilds workers from graph state.
  """

  use Jido,
    otp_app: :jido_code,
    storage: {Jido.Storage.ETS, [table: :jido_code_runtime_cache]}
end
