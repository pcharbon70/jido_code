defmodule JidoCode.Factory.Egress.Decision do
  @moduledoc "Bounded egress audit observation containing no URL query or body."

  alias JidoCode.Factory.Egress.Request

  @derive {Inspect,
           only: [
             :id,
             :outcome,
             :reason,
             :destination_digest,
             :method,
             :traffic_class,
             :integrity,
             :confidentiality,
             :request_bytes,
             :redirect_count,
             :occurred_at
           ]}
  @enforce_keys [
    :id,
    :outcome,
    :reason,
    :destination_digest,
    :method,
    :traffic_class,
    :integrity,
    :confidentiality,
    :request_bytes,
    :redirect_count,
    :attempt_iri,
    :invocation_iri,
    :occurred_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec issue(Request.t(), :allowed | :denied, atom(), DateTime.t()) :: t()
  def issue(%Request{} = request, outcome, reason, %DateTime{} = occurred_at)
      when outcome in [:allowed, :denied] and is_atom(reason) do
    policy = request.policy
    destination_digest = digest(request.uri)

    identity =
      Enum.join(
        [
          policy.policy_iri,
          policy.invocation_iri,
          destination_digest,
          Atom.to_string(request.method),
          Integer.to_string(request.redirect_count),
          Atom.to_string(outcome),
          Atom.to_string(reason),
          DateTime.to_iso8601(occurred_at)
        ],
        "\n"
      )

    %__MODULE__{
      id: digest(identity),
      outcome: outcome,
      reason: reason,
      destination_digest: destination_digest,
      method: request.method,
      traffic_class: request.traffic_class,
      integrity: request.integrity,
      confidentiality: request.confidentiality,
      request_bytes: request.request_bytes,
      redirect_count: request.redirect_count,
      attempt_iri: policy.attempt_iri,
      invocation_iri: policy.invocation_iri,
      occurred_at: occurred_at
    }
  end

  defp digest(value),
    do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, value), case: :lower)
end
