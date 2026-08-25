defmodule JidoCode.Factory.ManagedCoding.CancellationRequest do
  @moduledoc "Durable actor-attributed request to cancel one fenced managed attempt."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity

  @enforce_keys ~w[request_iri attempt_iri tenant_iri actor_iri reason target_fencing_token requested_at retention]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes),
         reason when is_binary(reason) and byte_size(reason) in 1..512 <- attributes[:reason],
         fence when is_integer(fence) and fence > 0 <- attributes[:target_fencing_token],
         %DateTime{} = requested_at <- attributes[:requested_at],
         retention when retention in [:clean, :quarantine] <- attributes[:retention],
         {:ok, request_iri} <- identity(attributes) do
      {:ok,
       struct!(__MODULE__, %{
         request_iri: request_iri,
         attempt_iri: attributes.attempt_iri,
         tenant_iri: attributes.tenant_iri,
         actor_iri: attributes.actor_iri,
         reason: reason,
         target_fencing_token: fence,
         requested_at: DateTime.truncate(requested_at, :microsecond),
         retention: retention
       })}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_cancellation)}
    end
  end

  def new(_attributes),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_cancellation)}

  defp resources(attributes) do
    if Enum.all?(~w[attempt_iri tenant_iri actor_iri]a, fn field ->
         Identity.validate_resource(attributes[field]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp identity(attributes) do
    Identity.deterministic(
      :cancellation_request,
      Enum.join(
        [attributes[:attempt_iri], attributes[:actor_iri], attributes[:target_fencing_token]],
        "\n"
      )
    )
  end
end
