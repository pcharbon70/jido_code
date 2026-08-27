defmodule JidoCode.Product.ManagedCodingControlGateway do
  @moduledoc "Authenticated finite operator controls translated into current-fence Factory commands."

  alias JidoCode.Factory.ManagedCoding
  alias JidoCode.Factory.ManagedCoding.Command
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Product.ManagedCodingAttempt
  alias JidoCode.Security.Redactor

  @actions ~w[steer answer cancel handoff recovery retry]a

  @spec submit(AuthorityContext.t(), map(), ManagedCodingAttempt.t(), atom(), map(), keyword()) ::
          ManagedCoding.result()
  def submit(authority, identity, attempt, action, params, options \\ [])

  def submit(
        %AuthorityContext{} = authority,
        identity,
        %ManagedCodingAttempt{} = attempt,
        action,
        params,
        options
      )
      when action in @actions and is_map(identity) and is_map(params) and is_list(options) do
    adapter =
      Keyword.get(options, :adapter, Application.get_env(:jido_code, :managed_coding_adapter))

    adapter_options = Keyword.get(options, :adapter_options, [])

    with true <- authority.actor_iri == attempt.actor_iri,
         true <- identity.actor_iri == authority.actor_iri,
         true <- state_allows?(attempt, action),
         :ok <- confirmation(action, params),
         :ok <- Redactor.reject_sensitive(params),
         {:ok, payload} <- payload(action, params),
         {:ok, command_iri} <- command_identity(attempt, action, params),
         {:ok, command} <- command(attempt, action, command_iri, payload),
         true <- is_atom(adapter) do
      apply(ManagedCoding, operation(action), [adapter, command, adapter_options])
    else
      _invalid ->
        {:error, JidoCode.Factory.AdapterError.new(:unauthorized, :managed_coding_control)}
    end
  rescue
    _error -> {:error, JidoCode.Factory.AdapterError.new(:invalid_input, :managed_coding_control)}
  end

  def submit(_authority, _identity, _attempt, _action, _params, _options),
    do: {:error, JidoCode.Factory.AdapterError.new(:invalid_input, :managed_coding_control)}

  defp confirmation(action, params) when action in [:cancel, :recovery, :retry] do
    if params["confirmed"] in [true, "true", "on", "1"], do: :ok, else: :error
  end

  defp confirmation(_action, _params), do: :ok

  defp payload(action, params) when action in [:steer, :answer] do
    message = params["message"] |> to_string() |> String.trim()

    if byte_size(message) in 1..2_000,
      do: {:ok, %{interaction: action, message: message}},
      else: :error
  end

  defp payload(:handoff, _params), do: {:ok, %{control: :candidate_handoff}}

  defp payload(action, _params) when action in [:cancel, :recovery, :retry],
    do: {:ok, %{control: normalized_action(action)}}

  defp command_identity(attempt, action, params) do
    idempotency_key = params["idempotency_key"]

    if is_binary(idempotency_key) and byte_size(idempotency_key) in 16..160 do
      ResourceIdentity.deterministic(
        :command_request,
        Enum.join([attempt.attempt_iri, attempt.fencing_token, action, idempotency_key], "\n")
      )
    else
      :error
    end
  end

  defp command(attempt, action, command_iri, payload) do
    Command.new(%{
      operation: operation(action),
      command_iri: command_iri,
      repository_iri: attempt.repository_iri,
      task_iri: attempt.task_iri,
      actor_iri: attempt.actor_iri,
      profile_iri: attempt.profile_iri,
      capability_iri: attempt.capability_iri,
      attempt_iri: attempt.attempt_iri,
      fencing_token: attempt.fencing_token,
      payload: payload
    })
  end

  defp state_allows?(attempt, :retry),
    do: ManagedCodingAttempt.control_available?(attempt, :recovery)

  defp state_allows?(attempt, action),
    do: ManagedCodingAttempt.control_available?(attempt, action)

  defp normalized_action(:retry), do: :accepted_recovery
  defp normalized_action(:recovery), do: :accepted_recovery
  defp normalized_action(action), do: action

  defp operation(:retry), do: :start
  defp operation(:recovery), do: :start
  defp operation(:answer), do: :steer
  defp operation(action), do: action
end
