defmodule JidoCode.Factory.ManagedCoding.Command do
  @moduledoc """
  Bounded command value accepted by the managed coding Factory facade.

  Admission binds task, repository, actor, profile, and capability. Every
  later operation additionally binds the durable attempt IRI and current
  positive fencing token. Payloads may contain bounded semantic references
  and classifications, never runtime implementation state.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @operations ~w[admit start steer cancel status handoff]a
  @enforce_keys [
    :operation,
    :command_iri,
    :repository_iri,
    :task_iri,
    :actor_iri,
    :profile_iri,
    :capability_iri,
    :payload
  ]
  defstruct @enforce_keys ++ [:attempt_iri, :fencing_token]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    resources = ~w[command_iri repository_iri task_iri actor_iri profile_iri capability_iri]a

    with operation when operation in @operations <- attributes[:operation],
         true <- Enum.all?(resources, &valid_resource?(attributes[&1])),
         :ok <- attempt_identity(operation, attributes),
         payload when is_map(payload) <- attributes[:payload],
         true <- bounded?(payload),
         false <- forbidden_runtime_state?(payload) do
      {:ok,
       struct!(__MODULE__, Map.take(attributes, @enforce_keys ++ [:attempt_iri, :fencing_token]))}
    else
      _invalid -> invalid(attributes[:operation] || :managed_coding_command)
    end
  rescue
    _error -> invalid(:managed_coding_command)
  end

  def new(_attributes), do: invalid(:managed_coding_command)

  defp attempt_identity(:admit, attributes) do
    if is_nil(attributes[:attempt_iri]) and is_nil(attributes[:fencing_token]),
      do: :ok,
      else: :error
  end

  defp attempt_identity(_operation, attributes) do
    with true <- valid_resource?(attributes[:attempt_iri]),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token] do
      :ok
    else
      _invalid -> :error
    end
  end

  defp valid_resource?(value), do: Knowledge.validate_resource_identity(value) == :ok

  defp bounded?(payload) do
    byte_size(:erlang.term_to_binary(payload, [:deterministic])) <= 16_384
  end

  defp forbidden_runtime_state?(payload) do
    forbidden =
      ~w[adapter adapter_module credential executable function graph_handle mfa module pid pod_pid provider_session secret store tool_arguments workspace_path]

    forbidden_value?(payload, forbidden)
  rescue
    _error -> true
  end

  defp forbidden_value?(value, _forbidden)
       when is_pid(value) or is_port(value) or is_reference(value),
       do: true

  defp forbidden_value?(value, forbidden) when is_map(value) do
    Enum.any?(value, fn {key, nested} ->
      normalized = key |> to_string() |> String.downcase()
      normalized in forbidden or forbidden_value?(nested, forbidden)
    end)
  end

  defp forbidden_value?(value, forbidden) when is_list(value),
    do: Enum.any?(value, &forbidden_value?(&1, forbidden))

  defp forbidden_value?(value, forbidden) when is_tuple(value),
    do: value |> Tuple.to_list() |> forbidden_value?(forbidden)

  defp forbidden_value?(_value, _forbidden), do: false

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
