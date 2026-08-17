defmodule JidoCode.Factory.Model.Profile do
  @moduledoc "Shared closed operations over admitted model profile types."

  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.Model.SubscriptionProfile

  @spec valid?(term()) :: boolean()
  def valid?(%BufferedProfile{} = profile), do: BufferedProfile.valid?(profile)
  def valid?(%SubscriptionProfile{} = profile), do: SubscriptionProfile.valid?(profile)
  def valid?(_profile), do: false

  @spec accepts?(BufferedProfile.t() | SubscriptionProfile.t(), Request.t()) :: boolean()
  def accepts?(%BufferedProfile{} = profile, %Request{} = request),
    do: BufferedProfile.accepts?(profile, request)

  def accepts?(%SubscriptionProfile{} = profile, %Request{} = request),
    do: SubscriptionProfile.accepts?(profile, request)

  def accepts?(_profile, _request), do: false
end
