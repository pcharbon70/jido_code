defmodule JidoCode.Knowledge.AuthorizationScope do
  @moduledoc false

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @spec digest(AuthorityContext.t(), String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def digest(%AuthorityContext{} = authority, scope_iri) do
    with :ok <- ResourceIdentity.validate(scope_iri) do
      digest =
        {
          authority.principal_iri,
          authority.actor_iri,
          authority.delegated_agent_iri,
          authority.delegation_iri,
          scope_iri
        }
        |> :erlang.term_to_binary([:deterministic])
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      {:ok, digest}
    end
  end

  def digest(_authority, _scope_iri),
    do: {:error, Error.new(:invalid_input, :authorization_scope)}
end
