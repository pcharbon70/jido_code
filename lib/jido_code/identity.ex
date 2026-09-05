defmodule JidoCode.Identity do
  @moduledoc """
  Named-human account and authentication boundary.

  Browser callers receive only safe outcomes and transient authentication
  results. Credential verifiers and mutable store state never cross this API.
  """

  alias JidoCode.Identity.Store

  defdelegate capabilities(server \\ Store), to: Store

  @spec bootstrap(map(), String.t(), keyword()) :: {:ok, struct()} | {:error, atom()}
  def bootstrap(attributes, credential, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.bootstrap(server, attributes, credential, call_options)
  end

  @spec authenticate(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def authenticate(login, credential, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.authenticate(server, login, credential, call_options)
  end

  @spec account(String.t(), keyword()) :: {:ok, struct()} | {:error, :not_found}
  def account(subject_ref, options \\ []) do
    Store.account(Keyword.get(options, :server, Store), subject_ref)
  end

  @spec authenticator(String.t(), keyword()) :: {:ok, struct()} | {:error, :not_found}
  def authenticator(authenticator_ref, options \\ []) do
    Store.authenticator(Keyword.get(options, :server, Store), authenticator_ref)
  end

  @spec rotate_credential(map(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, atom()}
  def rotate_credential(context, subject_ref, current, next, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.rotate_credential(server, context, subject_ref, current, next, call_options)
  end

  @spec disable_account(map(), String.t(), keyword()) :: {:ok, struct()} | {:error, atom()}
  def disable_account(context, subject_ref, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.disable_account(server, context, subject_ref, call_options)
  end

  @spec logout_all(map(), String.t(), keyword()) :: {:ok, struct()} | {:error, atom()}
  def logout_all(context, subject_ref, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.logout_all(server, context, subject_ref, call_options)
  end

  @spec recover_account(map(), String.t(), String.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, atom()}
  def recover_account(context, subject_ref, next, evidence, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.recover_account(server, context, subject_ref, next, evidence, call_options)
  end

  @spec evidence(:authentication | :recovery | :audit, keyword()) :: [struct()]
  def evidence(kind, options \\ []) do
    Store.evidence(Keyword.get(options, :server, Store), kind)
  end
end
