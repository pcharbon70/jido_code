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
      MapSet.new(
        ~w[pid pod_pid graph_handle store provider_session workspace_path credential secret]
      )

    Enum.any?(payload, fn {key, value} ->
      normalized = if is_binary(key), do: key, else: to_string(key)
      MapSet.member?(forbidden, normalized) or runtime_value?(value)
    end)
  rescue
    _error -> true
  end

  defp runtime_value?(value) when is_pid(value) or is_port(value) or is_reference(value), do: true
  defp runtime_value?(_value), do: false

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
