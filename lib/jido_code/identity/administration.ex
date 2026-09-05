defmodule JidoCode.Identity.Administration do
  @moduledoc "Governed identity membership, delegation, resource, and generation boundary."

  alias JidoCode.Identity.Store

  def enroll_account(context, attributes, credential, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.enroll_account(server, context, attributes, credential, call_options)
  end

  def put_membership(context, attributes, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.put_membership(server, context, attributes, call_options)
  end

  def revoke_membership(context, membership_ref, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.revoke_membership(server, context, membership_ref, call_options)
  end

  def put_delegation(context, attributes, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.put_delegation(server, context, attributes, call_options)
  end

  def revoke_delegation(context, delegation_ref, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.revoke_delegation(server, context, delegation_ref, call_options)
  end

  def register_resource(context, attributes, options \\ []) do
    {server, call_options} = Keyword.pop(options, :server, Store)
    Store.register_resource(server, context, attributes, call_options)
  end

  def publish_generation(context, attributes, options \\ [])

  def publish_generation(context, attributes, options) when is_map(attributes) do
    {server, call_options} = Keyword.pop(options, :server, Store)

    Store.publish_generation(
      server,
      Map.put(attributes, :context, context),
      call_options
    )
  end

  def publish_generation(_context, _attributes, _options),
    do: {:error, :invalid_generation_transition}
end
