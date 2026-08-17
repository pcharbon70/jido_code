defmodule JidoCode.Factory.CredentialBroker do
  @moduledoc "Linearizable credential release directly from a vault to an attested connector."

  use GenServer

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Credential.Permit
  alias JidoCode.Factory.Credential.Policy
  alias JidoCode.Factory.Credential.ReleaseRequest

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, options, Keyword.take(options, [:name]))
  end

  @spec release(GenServer.server(), ReleaseRequest.t(), map(), {module(), term()}, map()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def release(server, request, current, connector, payload)

  def release(
        server,
        %ReleaseRequest{} = request,
        current,
        {module, connector},
        payload
      )
      when is_map(current) and is_atom(module) and is_map(payload) do
    GenServer.call(server, {:release, request, current, module, connector, payload}, :infinity)
  end

  def release(_server, _request, _current, _connector, _payload),
    do: {:error, AdapterError.new(:invalid_input, :credential_release)}

  @impl true
  def init(options) do
    with {module, vault} when is_atom(module) <- Keyword.get(options, :vault),
         true <- vault?(module),
         clock when is_function(clock, 0) <- Keyword.get(options, :clock, &DateTime.utc_now/0) do
      {:ok, %{vault_module: module, vault: vault, clock: clock, used_permits: MapSet.new()}}
    else
      _invalid -> {:stop, AdapterError.new(:invalid_input, :credential_broker)}
    end
  end

  @impl true
  def handle_call(
        {:release, request, current, connector_module, connector, payload},
        _from,
        state
      ) do
    policy = request.policy
    now = state.clock.()

    with :ok <- current_authority(policy, current, now),
         true <- safe_payload?(payload),
         true <- connector?(connector_module),
         {:ok, identity} <- connector_module.identity(connector),
         :ok <- connector_identity(policy, identity),
         permit <- Permit.issue(request),
         false <- policy.single_use and MapSet.member?(state.used_permits, permit.id) do
      next_state = consume(state, policy, permit)
      result = dispatch(state, request, permit, connector_module, connector, payload)
      {:reply, result, next_state}
    else
      true -> {:reply, conflict(:credential_permit_reuse), state}
      false -> {:reply, unauthorized(:credential_release), state}
      {:error, %AdapterError{} = error} -> {:reply, {:error, error}, state}
      _invalid -> {:reply, unauthorized(:credential_release), state}
    end
  rescue
    _error -> {:reply, unavailable(:credential_release), state}
  catch
    :exit, _reason -> {:reply, unavailable(:credential_release), state}
  end

  defp dispatch(state, request, permit, connector_module, connector, payload) do
    with {:ok, delivery} <- credential_delivery(state, request.policy, permit),
         {:ok, result} <- connector_module.execute(connector, permit, delivery, payload),
         true <- safe_result?(result) do
      {:ok,
       %{
         permit: permit,
         connector_result: result,
         credential_class: request.policy.credential_class,
         enforced_restrictions: %{
           provider: request.policy.provider,
           audience: request.audience,
           scopes: request.minimum_scopes,
           enforcement: request.policy.enforcement
         }
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> {:error, AdapterError.new(:corrupt, :trusted_connector_result)}
    end
  end

  defp credential_delivery(
         _state,
         %Policy{credential_class: :local_cli_reference} = policy,
         _permit
       ),
       do: {:ok, {:local_cli_reference, policy.reference.iri}}

  defp credential_delivery(state, policy, permit) do
    case state.vault_module.checkout(state.vault, policy.reference, permit) do
      {:ok, material} when is_binary(material) and byte_size(material) in 1..16_384 ->
        {:ok, material}

      {:error, %AdapterError{} = error} ->
        {:error, error}

      _invalid ->
        unavailable(:credential_vault_checkout)
    end
  end

  defp current_authority(policy, current, now) do
    valid? =
      match?(%DateTime{}, now) and DateTime.compare(now, policy.expires_at) in [:lt, :eq] and
        current[:lease_state] == :active and current[:actor_iri] == policy.actor_iri and
        current[:delegated_agent_iri] == policy.delegated_agent_iri and
        current[:delegation_iri] == policy.delegation_iri and
        current[:repository_iri] == policy.repository_iri and
        current[:provider] == policy.provider and current[:attempt_iri] == policy.attempt_iri and
        current[:lease_iri] == policy.lease_iri and
        current[:fencing_token] == policy.fencing_token and
        current[:profile_revision] == policy.profile_revision and
        current[:credential_revision] == policy.credential_revision and
        current[:revocation_generation] == policy.revocation_generation and
        current[:invocation_iri] == policy.invocation_iri

    if valid?, do: :ok, else: unauthorized(:credential_authority)
  end

  defp connector_identity(policy, identity) when is_map(identity) do
    with name when is_binary(name) <- identity[:name],
         digest when is_binary(digest) <- identity[:digest],
         true <- Regex.match?(~r/^sha256:[a-f0-9]{64}$/, digest),
         true <- identity[:trusted] == true,
         :direct <- identity[:delivery],
         classes when is_list(classes) <- identity[:credential_classes],
         true <- policy.credential_class in classes,
         true <- policy.trusted_connector_identity == name <> "@" <> digest do
      :ok
    else
      _invalid -> unauthorized(:trusted_connector_identity)
    end
  end

  defp connector_identity(_policy, _identity), do: unauthorized(:trusted_connector_identity)

  defp consume(state, %Policy{single_use: true}, permit),
    do: update_in(state, [:used_permits], &MapSet.put(&1, permit.id))

  defp consume(state, _policy, _permit), do: state

  defp safe_payload?(payload) do
    byte_size(:erlang.term_to_binary(payload, [:deterministic])) <= 32_768 and
      not sensitive?(payload)
  end

  defp safe_result?(result) when is_map(result) do
    byte_size(:erlang.term_to_binary(result, [:deterministic])) <= 32_768 and
      not sensitive?(result)
  end

  defp safe_result?(_result), do: false

  defp sensitive?(value) when is_map(value) do
    Enum.any?(value, fn {key, item} -> sensitive_key?(key) or sensitive?(item) end)
  end

  defp sensitive?(value) when is_list(value), do: Enum.any?(value, &sensitive?/1)
  defp sensitive?(value) when is_tuple(value), do: value |> Tuple.to_list() |> sensitive?()

  defp sensitive?(value) when is_binary(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret|credential)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp sensitive?(_value), do: false

  defp sensitive_key?(key) when is_atom(key),
    do: key in [:password, :token, :secret, :credential, :api_key, :authorization]

  defp sensitive_key?(key) when is_binary(key),
    do: String.downcase(key) in ~w[password token secret credential api_key authorization]

  defp sensitive_key?(_key), do: false

  defp connector?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :identity, 1) and
      function_exported?(module, :execute, 4)
  end

  defp vault?(module),
    do: Code.ensure_loaded?(module) and function_exported?(module, :checkout, 3)

  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
end
