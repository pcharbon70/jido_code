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

  @spec managed(String.t(), keyword()) :: {:ok, [map()]} | {:error, atom()}
  def managed(current_session_ref, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.managed_sessions(server, current_session_ref, call_options)
  end

  @spec revoke_managed(String.t(), String.t(), keyword()) ::
          {:ok, :current | :other} | {:error, atom()}
  def revoke_managed(current_session_ref, management_ref, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.revoke_managed_session(server, current_session_ref, management_ref, call_options)
  end
end
