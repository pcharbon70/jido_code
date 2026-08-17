defmodule JidoCode.Factory.Credential.ReleaseRequest do
  @moduledoc "Bounded request for one exact credential policy and invocation."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Credential.Policy

  @derive {Inspect,
           only: [:operation, :audience, :minimum_scopes, :invocation_iri, :managed_claim]}
  @enforce_keys [:policy, :operation, :audience, :minimum_scopes, :invocation_iri, :managed_claim]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Policy.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%Policy{} = policy, attributes) when is_map(attributes) do
    minimum_scopes = attributes[:minimum_scopes]

    with true <- attributes[:operation] == policy.operation,
         true <- attributes[:audience] == policy.audience,
         true <- attributes[:invocation_iri] == policy.invocation_iri,
         true <- is_list(minimum_scopes) and minimum_scopes != [],
         true <- minimum_scopes == Enum.uniq(minimum_scopes),
         true <- MapSet.subset?(MapSet.new(minimum_scopes), MapSet.new(policy.scopes)),
         true <- is_boolean(attributes[:managed_claim]),
         true <- not attributes[:managed_claim] or policy.managed_eligible do
      {:ok,
       %__MODULE__{
         policy: policy,
         operation: policy.operation,
         audience: policy.audience,
         minimum_scopes: Enum.sort(minimum_scopes),
         invocation_iri: policy.invocation_iri,
         managed_claim: attributes.managed_claim
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_policy, _attributes), do: invalid()
  defp invalid, do: {:error, AdapterError.new(:unauthorized, :credential_release_request)}
end
