defmodule JidoCode.Factory.Credential.Permit do
  @moduledoc "Opaque one-release authorization receipt containing no credential material."

  alias JidoCode.Factory.Credential.Policy
  alias JidoCode.Factory.Credential.ReleaseRequest

  @derive {Inspect,
           only: [
             :id,
             :credential_reference_iri,
             :credential_class,
             :operation,
             :audience,
             :scopes,
             :enforcement,
             :expires_at,
             :single_use
           ]}
  @enforce_keys [
    :id,
    :credential_reference_iri,
    :credential_class,
    :operation,
    :audience,
    :scopes,
    :enforcement,
    :expires_at,
    :single_use,
    :invocation_iri,
    :attempt_iri,
    :fencing_token,
    :connector_identity
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec issue(ReleaseRequest.t()) :: t()
  def issue(%ReleaseRequest{policy: %Policy{} = policy} = request) do
    material =
      Enum.join(
        [
          policy.reference.iri,
          request.operation,
          request.audience,
          Enum.join(request.minimum_scopes, ","),
          request.invocation_iri,
          policy.attempt_iri,
          Integer.to_string(policy.fencing_token),
          policy.trusted_connector_identity,
          DateTime.to_iso8601(policy.expires_at),
          Integer.to_string(policy.profile_revision),
          Integer.to_string(policy.credential_revision),
          Integer.to_string(policy.revocation_generation)
        ],
        "\n"
      )

    %__MODULE__{
      id: "sha256:" <> Base.encode16(:crypto.hash(:sha256, material), case: :lower),
      credential_reference_iri: policy.reference.iri,
      credential_class: policy.credential_class,
      operation: request.operation,
      audience: request.audience,
      scopes: request.minimum_scopes,
      enforcement: policy.enforcement,
      expires_at: policy.expires_at,
      single_use: policy.single_use,
      invocation_iri: policy.invocation_iri,
      attempt_iri: policy.attempt_iri,
      fencing_token: policy.fencing_token,
      connector_identity: policy.trusted_connector_identity
    }
  end
end
