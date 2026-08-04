defmodule JidoCode.Product.CommandGateway do
  @moduledoc """
  Server-owned constructor for finite product semantic intents.

  Browser input supplies workflow values only. Graph names, command types,
  revisions, actor identity, scope, and semantic resource identities are
  resolved here from trusted session context and current graph state.
  """

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Repositories.Enrollment
  alias JidoCode.Knowledge.Repositories.Locator
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Product.CommandOutcome
  alias JidoCode.Security.Redactor

  @valid_to ~U[9999-12-31 23:59:59Z]
  @max_value_bytes 160

  @spec enroll_repository(AuthorityContext.t(), map(), map(), keyword()) ::
          {:ok, CommandOutcome.t()} | {:error, Error.t()}
  def enroll_repository(authority, identity, params, options \\ [])

  def enroll_repository(%AuthorityContext{} = authority, identity, params, options)
      when is_map(identity) and is_map(params) and is_list(options) do
    clock = Keyword.get(options, :clock, &DateTime.utc_now/0)
    summary = Keyword.get(options, :summary, &StoreServer.summary/0)
    metadata = Keyword.get(options, :metadata, &QueryRunner.graph_metadata/1)
    execute = Keyword.get(options, :execute, &Knowledge.execute/1)

    with :ok <-
           Redactor.reject_sensitive(
             Map.take(params, ~w[conceptual_key provider external_id owner name reason])
           ),
         {:ok, input} <- validate_input(params),
         true <- input.confirmed?,
         %DateTime{} = recorded_at <- clock.() |> DateTime.truncate(:microsecond),
         {:ok, catalog_graph} <- GraphRegistry.graph_iri(:factory_catalog, %{}),
         %{dataset_revision: dataset_revision} <- summary.(),
         true <- is_integer(dataset_revision) and dataset_revision >= 0,
         {:ok, %{graph_revision: catalog_revision}} <- metadata.(catalog_graph),
         {:ok, repository_iri} <- ResourceIdentity.conceptual_repository(input.conceptual_key),
         {:ok, repository_scope_iri} <- ResourceIdentity.scope(:repository, repository_iri),
         {:ok, locator} <- locator(input, recorded_at),
         {:ok, request_iri} <- request_iri(authority, input.idempotency_key),
         {:ok, enrollment} <-
           enrollment(
             authority,
             identity,
             input,
             locator,
             request_iri,
             repository_iri,
             repository_scope_iri,
             recorded_at
           ),
         {:ok, command} <-
           command(
             authority,
             identity,
             input,
             enrollment,
             request_iri,
             catalog_graph,
             dataset_revision,
             catalog_revision,
             recorded_at
           ),
         {:ok, %CommandReceipt{} = receipt} <- execute.(command) do
      {:ok, CommandOutcome.from_receipt(receipt)}
    else
      false -> invalid(:enrollment_confirmation)
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:enroll_repository_intent)
    end
  rescue
    _error -> invalid(:enroll_repository_intent)
  catch
    :exit, _reason -> {:error, Error.new(:unavailable, :enroll_repository_intent)}
  end

  def enroll_repository(_authority, _identity, _params, _options),
    do: invalid(:enroll_repository_intent)

  defp enrollment(
         authority,
         identity,
         input,
         locator,
         request_iri,
         repository_iri,
         repository_scope_iri,
         recorded_at
       ) do
    Enrollment.new(%{
      factory_iri: identity.factory_iri,
      repository_iri: repository_iri,
      repository_scope_iri: repository_scope_iri,
      policy_boundary_iri: identity.policy_boundary_iri,
      policy_iris: identity.policy_iris,
      locator: locator,
      actor_iri: authority.actor_iri,
      cause_iri: request_iri,
      reason: input.reason,
      valid_from: recorded_at,
      valid_to: @valid_to,
      initial_state: :active
    })
  end

  defp command(
         authority,
         identity,
         input,
         enrollment,
         request_iri,
         catalog_graph,
         dataset_revision,
         catalog_revision,
         recorded_at
       ) do
    Enrollment.enroll_command(
      enrollment,
      %{
        command_iri: request_iri,
        principal_iri: authority.principal_iri,
        delegated_agent_iri: authority.delegated_agent_iri,
        delegation_iri: authority.delegation_iri,
        factory_scope_iri: identity.factory_scope_iri,
        idempotency_key: input.idempotency_key,
        correlation_iri: request_iri,
        causation_iri: request_iri,
        expected_dataset_revision: dataset_revision,
        catalog_graph_iri: catalog_graph,
        expected_catalog_revision: catalog_revision,
        reason: input.reason
      },
      clock: fn -> recorded_at end
    )
  end

  defp request_iri(authority, idempotency_key) do
    ResourceIdentity.deterministic(
      :command_request,
      Enum.join([authority.actor_iri, "enroll-repository", idempotency_key], "\n")
    )
  end

  defp validate_input(params) do
    with {:ok, conceptual_key} <- value(params, "conceptual_key"),
         {:ok, provider} <- value(params, "provider"),
         {:ok, external_id} <- value(params, "external_id"),
         {:ok, owner} <- value(params, "owner"),
         {:ok, name} <- value(params, "name"),
         {:ok, reason} <- value(params, "reason"),
         {:ok, idempotency_key} <- idempotency(params["idempotency_key"]),
         confirmed? <- params["confirmed"] in ["true", true] do
      {:ok,
       %{
         conceptual_key: conceptual_key,
         provider: provider,
         external_id: external_id,
         owner: owner,
         name: name,
         reason: reason,
         idempotency_key: idempotency_key,
         confirmed?: confirmed?
       }}
    end
  end

  defp value(params, key) do
    case params[key] do
      value when is_binary(value) ->
        value = String.trim(value)

        if value != "" and byte_size(value) <= @max_value_bytes,
          do: {:ok, value},
          else: invalid(:enrollment_form)

      _invalid ->
        invalid(:enrollment_form)
    end
  end

  defp idempotency(value) when is_binary(value) do
    if byte_size(value) in 16..96 and Regex.match?(~r/^[A-Za-z0-9_-]+$/, value),
      do: {:ok, value},
      else: invalid(:enrollment_idempotency)
  end

  defp idempotency(_value), do: invalid(:enrollment_idempotency)

  defp locator(input, recorded_at) do
    Locator.new(%{
      provider: input.provider,
      external_id: input.external_id,
      owner: input.owner,
      name: input.name,
      state: :active,
      observed_at: recorded_at,
      relationships: []
    })
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
