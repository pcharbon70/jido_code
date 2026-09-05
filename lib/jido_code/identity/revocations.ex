defmodule JidoCode.Identity.Revocations do
  @moduledoc "Application-owned revocation notification boundary."

  alias JidoCode.Identity.RevocationEvent

  @topic "identity:revocations"
  @dimensions ~w[account session role delegation project tenant graph incident]a

  def dimensions, do: @dimensions

  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    Phoenix.PubSub.subscribe(JidoCode.PubSub, @topic)
  catch
    :exit, reason -> {:error, reason}
  end

  @spec publish(RevocationEvent.t()) :: :ok
  def publish(%RevocationEvent{dimension: dimension} = event) when dimension in @dimensions do
    Phoenix.PubSub.broadcast(JidoCode.PubSub, @topic, {:identity_revoked, event})
  catch
    :exit, _reason -> :ok
  end
end
