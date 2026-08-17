defmodule JidoCode.Factory.Model.LiveConsent do
  @moduledoc "Explicit opt-in gate for subscription tests that contact a live provider."

  alias JidoCode.Factory.AdapterError

  @spec authorize(keyword()) :: :ok | {:error, AdapterError.t()}
  def authorize(options) when is_list(options) do
    if Keyword.get(options, :consent) == :granted and
         Keyword.get(options, :live_test) == true and
         System.get_env("JIDO_CODE_LIVE_SUBSCRIPTION_TESTS") == "1" do
      :ok
    else
      {:error, AdapterError.new(:unauthorized, :live_subscription_test)}
    end
  end

  def authorize(_options),
    do: {:error, AdapterError.new(:invalid_input, :live_subscription_test)}
end
