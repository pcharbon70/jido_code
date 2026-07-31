defmodule JidoCode.TestSupport.RestartGateNative do
  @moduledoc false

  @owner_key {__MODULE__, :owner}
  @count_key {__MODULE__, :count}

  def configure(owner) when is_pid(owner) do
    :persistent_term.put(@owner_key, owner)
    :persistent_term.put(@count_key, 0)
    :ok
  end

  def clear do
    :persistent_term.erase(@owner_key)
    :persistent_term.erase(@count_key)
    :ok
  end

  def verify do
    count = :persistent_term.get(@count_key, 0) + 1
    :persistent_term.put(@count_key, count)

    if count > 1 do
      owner = :persistent_term.get(@owner_key)
      send(owner, {:native_verification_blocked, self()})

      receive do
        :release_native_verification -> :ok
      after
        10_000 -> :ok
      end
    else
      :ok
    end
  end
end
