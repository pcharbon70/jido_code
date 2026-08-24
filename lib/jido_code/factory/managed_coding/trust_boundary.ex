defmodule JidoCode.Factory.ManagedCoding.TrustBoundary do
  @moduledoc """
  Pure conformance checks applied before a managed coding effect is admitted.

  Repository content, model output, and tool arguments remain untrusted data.
  They cannot select authority, change the fence or context, spend an exhausted
  budget, disclose secrets, or attest their own completion.
  """

  @digest ~r/^[a-f0-9]{64}$/
  @secret_markers ["-----BEGIN PRIVATE KEY-----", "ghp_", "sk-", "aws_secret_access_key"]
  @runtime_keys ~w[adapter adapter_module credential executable function graph_handle mfa module pid pod_pid provider_session secret store workspace_path]

  @spec validate_payload(term()) :: :ok | {:error, :untrusted_runtime_payload}
  def validate_payload(payload) when is_map(payload) do
    if byte_size(:erlang.term_to_binary(payload, [:deterministic])) <= 32_768 and
         not forbidden_payload?(payload),
       do: :ok,
       else: {:error, :untrusted_runtime_payload}
  rescue
    _error -> {:error, :untrusted_runtime_payload}
  end

  def validate_payload(_payload), do: {:error, :untrusted_runtime_payload}

  @spec assess(map()) :: :ok | {:error, atom()}
  def assess(attributes) when is_map(attributes) do
    with :ok <- trusted_instructions(attributes[:instructions]),
         :ok <- tool_arguments(attributes[:tool_arguments]),
         :ok <- exact_capabilities(attributes),
         :ok <- current_fence(attributes),
         :ok <- exact_context(attributes),
         :ok <- no_secret_exposure(attributes[:candidate_output]),
         :ok <- budget_available(attributes[:budget_remaining]),
         :ok <- independent_verifier(attributes) do
      :ok
    end
  end

  def assess(_attributes), do: {:error, :invalid_conformance_fixture}

  defp trusted_instructions(instructions) when is_list(instructions) and instructions != [] do
    if Enum.all?(instructions, &match?(%{source: :factory, text: text} when is_binary(text), &1)),
      do: :ok,
      else: {:error, :repository_prompt_injection}
  end

  defp trusted_instructions(_instructions), do: {:error, :repository_prompt_injection}

  defp tool_arguments(arguments) when is_map(arguments) do
    forbidden = ~w[adapter adapter_module executable function mfa module]

    if nested_key?(arguments, forbidden),
      do: {:error, :tool_argument_smuggling},
      else: :ok
  end

  defp tool_arguments(_arguments), do: {:error, :tool_argument_smuggling}

  defp exact_capabilities(attributes) do
    admitted = normalized_list(attributes[:admitted_capabilities])
    current = normalized_list(attributes[:current_capabilities])

    if admitted != :error and admitted == current, do: :ok, else: {:error, :capability_drift}
  end

  defp current_fence(%{expected_fence: fence, presented_fence: fence})
       when is_integer(fence) and fence > 0,
       do: :ok

  defp current_fence(_attributes), do: {:error, :stale_fence}

  defp exact_context(%{expected_context_digest: digest, presented_context_digest: digest})
       when is_binary(digest) do
    if Regex.match?(@digest, digest), do: :ok, else: {:error, :context_substitution}
  end

  defp exact_context(_attributes), do: {:error, :context_substitution}

  defp no_secret_exposure(value) when is_binary(value) do
    normalized = String.downcase(value)

    if Enum.any?(@secret_markers, &String.contains?(normalized, String.downcase(&1))),
      do: {:error, :secret_exposure},
      else: :ok
  end

  defp no_secret_exposure(_value), do: {:error, :secret_exposure}

  defp budget_available(value) when is_integer(value) and value > 0, do: :ok
  defp budget_available(_value), do: {:error, :budget_exhausted}

  defp independent_verifier(%{runtime_actor_iri: actor, verifier_actor_iri: verifier})
       when is_binary(actor) and is_binary(verifier) and actor != verifier,
       do: :ok

  defp independent_verifier(_attributes), do: {:error, :self_verification}

  defp normalized_list(values) when is_list(values) and values != [] do
    if Enum.all?(values, &is_binary/1), do: values |> Enum.uniq() |> Enum.sort(), else: :error
  end

  defp normalized_list(_values), do: :error

  defp nested_key?(value, forbidden) when is_map(value) do
    Enum.any?(value, fn {key, nested} ->
      normalized = key |> to_string() |> String.downcase()
      normalized in forbidden or nested_key?(nested, forbidden)
    end)
  rescue
    _error -> true
  end

  defp nested_key?(value, forbidden) when is_list(value),
    do: Enum.any?(value, &nested_key?(&1, forbidden))

  defp nested_key?(_value, _forbidden), do: false

  defp forbidden_payload?(value) when is_pid(value) or is_port(value) or is_reference(value),
    do: true

  defp forbidden_payload?(value) when is_function(value), do: true

  defp forbidden_payload?(value) when is_map(value) do
    Enum.any?(value, fn {key, nested} ->
      normalized = key |> to_string() |> String.downcase()
      normalized in @runtime_keys or forbidden_payload?(nested)
    end)
  rescue
    _error -> true
  end

  defp forbidden_payload?(value) when is_list(value), do: Enum.any?(value, &forbidden_payload?/1)

  defp forbidden_payload?(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> forbidden_payload?()

  defp forbidden_payload?(_value), do: false
end
