defmodule JidoCode.Factory.ManagedCoding.Steering do
  @moduledoc "Graph-authorized, current-fence operator control for one managed attempt."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.TrustBoundary

  @operations ~w[steer pause resume cancel]a
  @enforce_keys [:operation, :attempt_iri, :fencing_token, :actor_iri, :payload]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec authorize(map(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def authorize(attributes, current) when is_map(attributes) and is_map(current) do
    with operation when operation in @operations <- attributes[:operation],
         :ok <- Identity.validate_resource(attributes[:attempt_iri]),
         :ok <- Identity.validate_resource(attributes[:actor_iri]),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         true <- current[:current?] == true,
         true <- current[:graph_authorized?] == true,
         true <- current[:attempt_iri] == attributes[:attempt_iri],
         true <- current[:fencing_token] == fence,
         true <- current[:actor_iri] == attributes[:actor_iri],
         payload when is_map(payload) <- attributes[:payload],
         :ok <- TrustBoundary.validate_payload(payload),
         false <- capability_language?(payload) do
      {:ok,
       %__MODULE__{
         operation: operation,
         attempt_iri: attributes.attempt_iri,
         fencing_token: fence,
         actor_iri: attributes.actor_iri,
         payload: payload
       }}
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :managed_coding_steering)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unauthorized, :managed_coding_steering)}
  end

  def authorize(_attributes, _current),
    do: {:error, AdapterError.new(:unauthorized, :managed_coding_steering)}

  defp capability_language?(payload) do
    payload
    |> :erlang.term_to_binary([:deterministic])
    |> then(&Regex.match?(~r/(capability|credential|permission|authority|adapter_module)/i, &1))
  end
end
