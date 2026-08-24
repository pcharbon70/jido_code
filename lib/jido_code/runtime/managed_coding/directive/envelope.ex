defmodule JidoCode.Runtime.ManagedCoding.Directive.Envelope do
  @moduledoc "Correlation and bounded payload shared by closed managed coding directives."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.TrustBoundary

  @kinds ~w[context model tool actor candidate observation continuation]a
  @enforce_keys [
    :attempt_iri,
    :fencing_token,
    :sequence,
    :kind,
    :invocation_iri,
    :deadline,
    :payload,
    :payload_digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(atom(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(kind, attributes) when kind in @kinds and is_map(attributes) do
    payload = attributes[:payload]

    with :ok <- Identity.validate_resource(attributes[:attempt_iri]),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         sequence when is_integer(sequence) and sequence > 0 <- attributes[:sequence],
         :ok <- Identity.validate_resource(attributes[:invocation_iri]),
         %DateTime{} = deadline <- attributes[:deadline],
         true <- DateTime.compare(deadline, DateTime.utc_now()) == :gt,
         payload when is_map(payload) and map_size(payload) <= 64 <- payload,
         :ok <- TrustBoundary.validate_payload(payload),
         true <- byte_size(:erlang.term_to_binary(payload, [:deterministic])) <= 32_768 do
      digest = digest({kind, payload})

      {:ok,
       %__MODULE__{
         attempt_iri: attributes.attempt_iri,
         fencing_token: fence,
         sequence: sequence,
         kind: kind,
         invocation_iri: attributes.invocation_iri,
         deadline: DateTime.truncate(deadline, :microsecond),
         payload: payload,
         payload_digest: digest
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_kind, _attributes), do: invalid()

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_directive)}
end
