defmodule JidoCode.Factory.ManagedCoding.EffectIntent do
  @moduledoc "Fence-bound durable identity for one external managed-coding effect."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.EffectPolicy
  alias JidoCode.Factory.ManagedCoding.Identity

  @enforce_keys ~w[intent_iri attempt_iri invocation_iri tenant_iri operation classification idempotency_key fencing_token requested_at]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes),
         {:ok, classification} <- EffectPolicy.classify(attributes[:operation]),
         key when is_binary(key) and byte_size(key) in 16..256 <- attributes[:idempotency_key],
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         %DateTime{} = requested_at <- attributes[:requested_at],
         {:ok, intent_iri} <- identity(attributes) do
      {:ok,
       struct!(__MODULE__, %{
         intent_iri: intent_iri,
         attempt_iri: attributes.attempt_iri,
         invocation_iri: attributes.invocation_iri,
         tenant_iri: attributes.tenant_iri,
         operation: attributes.operation,
         classification: classification,
         idempotency_key: key,
         fencing_token: fence,
         requested_at: DateTime.truncate(requested_at, :microsecond)
       })}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_effect_intent)}
    end
  end

  def new(_attributes),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_effect_intent)}

  defp resources(attributes) do
    if Enum.all?(~w[attempt_iri invocation_iri tenant_iri]a, fn field ->
         Identity.validate_resource(attributes[field]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp identity(attributes) do
    Identity.deterministic(
      :execution_event,
      Enum.join(
        [attributes[:attempt_iri], attributes[:invocation_iri], attributes[:idempotency_key]],
        "\n"
      )
    )
  end
end
