defmodule JidoCode.Runtime.AttemptRegistry do
  @moduledoc false

  alias JidoCode.Factory.Execution.Request

  @spec key(Request.t()) :: String.t()
  def key(%Request{} = request), do: Request.runtime_key(request)

  @spec via(Request.t()) :: {:via, Registry, {module(), String.t()}}
  def via(%Request{} = request), do: {:via, Registry, {__MODULE__, key(request)}}

  @spec lookup(Request.t()) :: {:ok, pid()} | :error
  def lookup(%Request{} = request) do
    case Registry.lookup(__MODULE__, key(request)) do
      [{pid, _value}] -> if Process.alive?(pid), do: {:ok, pid}, else: :error
      [] -> :error
    end
  end
end
