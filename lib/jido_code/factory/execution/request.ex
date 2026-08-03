defmodule JidoCode.Factory.Execution.Request do
  @moduledoc """
  Bounded semantic identity passed to an execution runtime.

  Provider sessions, process identifiers, graph handles, and sandbox paths are
  deliberately absent. The value is disposable and can be rebuilt from graph
  projections.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @enforce_keys [
    :attempt_iri,
    :lease_iri,
    :task_iri,
    :goal_iri,
    :plan_iri,
    :repository_iri,
    :snapshot_iri,
    :actor_iri,
    :agent_iri,
    :capability_iri,
    :fencing_token,
    :context_digest,
    :runtime_version,
    :constraints
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    resources =
      ~w[attempt_iri lease_iri task_iri goal_iri plan_iri repository_iri snapshot_iri actor_iri agent_iri capability_iri]a

    with true <-
           Enum.all?(resources, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         digest when is_binary(digest) <- attributes[:context_digest],
         true <- Regex.match?(~r/^[a-f0-9]{64}$/, digest),
         version when is_binary(version) <- attributes[:runtime_version],
         true <- byte_size(version) in 1..128,
         constraints when is_map(constraints) <- attributes[:constraints],
         true <- bounded?(constraints, 32_768) do
      {:ok, struct!(__MODULE__, Map.take(attributes, @enforce_keys))}
    else
      _invalid -> invalid(:execution_request)
    end
  rescue
    _error -> invalid(:execution_request)
  end

  def new(_attributes), do: invalid(:execution_request)

  @spec runtime_key(t()) :: String.t()
  def runtime_key(%__MODULE__{} = request) do
    :crypto.hash(:sha256, request.attempt_iri <> "\n" <> Integer.to_string(request.fencing_token))
    |> Base.encode16(case: :lower)
  end

  defp bounded?(value, limit) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> byte_size()
    |> Kernel.<=(limit)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
