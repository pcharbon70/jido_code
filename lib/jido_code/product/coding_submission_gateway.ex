defmodule JidoCode.Product.CodingSubmissionGateway do
  @moduledoc "Validates one semantic task submission before graph admission and fenced dispatch."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.GraphCodingSubmissionProvider
  alias JidoCode.Product.WorkflowOutcome
  alias JidoCode.Security.Redactor

  @allowed ~w[intent repository_ref snapshot_ref task_class acceptance_requirements offering_ref idempotency_key foreground_consent billing_acknowledged]

  @spec submit(AuthorityContext.t(), map(), map(), keyword()) ::
          {:ok, WorkflowOutcome.t()} | {:error, AdapterError.t()}
  def submit(authority, identity, params, options \\ [])

  def submit(%AuthorityContext{} = authority, identity, params, options)
      when is_map(identity) and is_map(params) and is_list(options) do
    provider = Keyword.get(options, :provider, GraphCodingSubmissionProvider)

    with true <- authority.actor_iri == identity.actor_iri,
         true <- Map.keys(params) |> Enum.all?(&(to_string(&1) in @allowed)),
         :ok <- Redactor.reject_sensitive(params),
         {:ok, request} <- request(identity, params),
         {:ok, %WorkflowOutcome{} = outcome} <-
           provider_submit(provider, authority, identity, request) do
      {:ok, outcome}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      {:error, :unavailable} -> error(:unavailable)
      _invalid -> error(:invalid_input)
    end
  rescue
    _error -> error(:invalid_input)
  end

  def submit(_authority, _identity, _params, _options), do: error(:invalid_input)

  defp request(identity, params) do
    with {:ok, intent} <- text(params, "intent", 8_000),
         {:ok, repository_ref} <- ref(params, "repository_ref"),
         {:ok, snapshot_ref} <- ref(params, "snapshot_ref"),
         {:ok, task_class} <- identifier(params, "task_class"),
         {:ok, acceptance} <- acceptance(params),
         {:ok, offering_ref} <- ref(params, "offering_ref"),
         {:ok, idempotency_key} <- idempotency(params),
         true <- truthy?(value(params, "foreground_consent")),
         true <- truthy?(value(params, "billing_acknowledged")) do
      {:ok,
       %{
         semantic_intent: intent,
         repository_ref: repository_ref,
         snapshot_ref: snapshot_ref,
         task_class: task_class,
         acceptance_requirements: acceptance,
         offering_ref: offering_ref,
         actor_iri: identity.actor_iri,
         tenant_iri: identity.factory_scope_iri,
         idempotency_key: idempotency_key,
         foreground_consent: true,
         billing_acknowledged: true
       }}
    else
      _invalid -> :error
    end
  end

  defp provider_submit(provider, authority, identity, request) when is_atom(provider) do
    if Code.ensure_loaded?(provider) and function_exported?(provider, :submit, 3),
      do: provider.submit(authority, identity, request),
      else: {:error, :unavailable}
  end

  defp provider_submit(provider, authority, identity, request) when is_function(provider, 3),
    do: provider.(authority, identity, request)

  defp provider_submit(_provider, _authority, _identity, _request), do: {:error, :unavailable}

  defp acceptance(params) do
    case value(params, "acceptance_requirements") do
      values when is_list(values) and length(values) in 1..32 ->
        Enum.reduce_while(values, {:ok, []}, fn item, {:ok, acc} ->
          if is_binary(item) and byte_size(item) in 1..240,
            do: {:cont, {:ok, [String.trim(item) | acc]}},
            else: {:halt, :error}
        end)
        |> case do
          {:ok, values} -> {:ok, Enum.reverse(values)}
          :error -> :error
        end

      value when is_binary(value) ->
        value
        |> String.split("\n", trim: true)
        |> acceptance_from_lines()

      _invalid ->
        :error
    end
  end

  defp acceptance_from_lines(lines) when length(lines) in 1..32 do
    if Enum.all?(lines, &(byte_size(&1) in 1..240)), do: {:ok, lines}, else: :error
  end

  defp acceptance_from_lines(_lines), do: :error

  defp text(params, key, maximum) do
    case value(params, key) do
      value when is_binary(value) ->
        value = String.trim(value)
        if byte_size(value) in 1..maximum, do: {:ok, value}, else: :error

      _invalid ->
        :error
    end
  end

  defp ref(params, key) do
    with {:ok, value} <- text(params, key, 160),
         true <- byte_size(value) >= 16,
         true <- Regex.match?(~r/^[A-Za-z0-9_-]+$/, value) do
      {:ok, value}
    else
      _invalid -> :error
    end
  end

  defp identifier(params, key) do
    with {:ok, value} <- text(params, key, 64),
         true <- Regex.match?(~r/^[a-z][a-z0-9_]*$/, value) do
      {:ok, value}
    else
      _invalid -> :error
    end
  end

  defp idempotency(params) do
    with {:ok, value} <- text(params, "idempotency_key", 96),
         true <- byte_size(value) >= 16,
         true <- Regex.match?(~r/^[A-Za-z0-9_-]+$/, value) do
      {:ok, value}
    else
      _invalid -> :error
    end
  end

  defp value(params, key) do
    Map.get(params, key) ||
      Enum.find_value(params, fn
        {field, value} when is_atom(field) -> if Atom.to_string(field) == key, do: value
        _entry -> nil
      end)
  end

  defp truthy?(value), do: value in [true, "true", "on", "1"]
  defp error(kind), do: {:error, AdapterError.new(kind, :coding_submission_gateway)}
end
