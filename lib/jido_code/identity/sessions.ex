defmodule JidoCode.Identity.Sessions do
  @moduledoc "Named-human server-side browser session boundary."

  alias JidoCode.Identity.Store

  @spec issue(map(), keyword()) :: {:ok, struct()} | {:error, atom()}
  def issue(authentication, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.issue_session(server, authentication, call_options)
  end

  @spec validate(String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def validate(session_ref, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.validate_session(server, session_ref, call_options)
  end

  @spec revoke(map(), String.t(), keyword()) :: :ok | {:error, atom()}
  def revoke(context, session_ref, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.revoke_session(server, context, session_ref, call_options)
  end
end
