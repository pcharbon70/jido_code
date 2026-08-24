defmodule JidoCode.Factory.ManagedCoding.ActorSession do
  @moduledoc "Purpose-bound clarification session that cannot widen coding authority."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.TrustBoundary

  @purposes ~w[clarify_task choose_alternative supply_missing_input]a
  @enforce_keys [
    :iri,
    :attempt_iri,
    :fencing_token,
    :purpose,
    :audience_iri,
    :expires_at,
    :maximum_response_bytes
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Identity.validate_resource(attributes[:iri]),
         :ok <- Identity.validate_resource(attributes[:attempt_iri]),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         purpose when purpose in @purposes <- attributes[:purpose],
         :ok <- Identity.validate_resource(attributes[:audience_iri]),
         %DateTime{} <- attributes[:expires_at],
         maximum when is_integer(maximum) and maximum in 1..16_384 <-
           attributes[:maximum_response_bytes] do
      {:ok, struct!(__MODULE__, Map.take(attributes, @enforce_keys))}
    else
      _invalid -> invalid(:managed_coding_actor_session)
    end
  rescue
    _error -> invalid(:managed_coding_actor_session)
  end

  def new(_attributes), do: invalid(:managed_coding_actor_session)

  @spec accept(t(), map(), DateTime.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def accept(%__MODULE__{} = session, response, %DateTime{} = now) when is_map(response) do
    content = response[:content]

    with true <- response[:attempt_iri] == session.attempt_iri,
         true <- response[:fencing_token] == session.fencing_token,
         true <- response[:actor_iri] == session.audience_iri,
         true <- DateTime.compare(now, session.expires_at) == :lt,
         true <- is_binary(content) and byte_size(content) in 1..session.maximum_response_bytes,
         :ok <- TrustBoundary.validate_payload(%{content: content}),
         false <- authority_language?(content) do
      {:ok, %{content: content, actor_iri: session.audience_iri, purpose: session.purpose}}
    else
      _invalid -> invalid(:managed_coding_actor_response)
    end
  end

  def accept(_session, _response, _now), do: invalid(:managed_coding_actor_response)

  defp authority_language?(content) do
    Regex.match?(~r/\b(grant|authorize|permission|capability|credential|bypass|sudo)\b/i, content)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
