defmodule JidoCode.Knowledge.Memory.ProcedureAuthority do
  @moduledoc "Keeps validated guidance, accepted propositions, and executable policy as separate contracts."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ProcedureRevision
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"

  def revision, do: @revision

  def knowledge_proposition(%ProcedureRevision{} = procedure, validation, attributes) do
    with %{transition: %{next_state: :validated}, evidence_iri: evidence} <- validation,
         :ok <- ResourceIdentity.validate(evidence),
         :ok <- ResourceIdentity.validate(attributes[:decision_iri]),
         proposition when is_binary(proposition) and byte_size(proposition) in 1..1_024 <-
           attributes[:proposition] do
      {:ok,
       %{
         revision: @revision,
         procedure_iri: procedure.iri,
         proposition: proposition,
         evidence_iri: evidence,
         decision_iri: attributes.decision_iri,
         adoptable_only_via: "AdoptKnowledge",
         executable?: false
       }}
    else
      _invalid -> {:error, Error.new(:unauthorized, :procedure_knowledge_boundary)}
    end
  end

  def sanitized_policy(%ProcedureRevision{} = procedure, validation, attributes) do
    with %{transition: %{next_state: :validated}} <- validation,
         :ok <- ResourceIdentity.validate(attributes[:policy_iri]),
         true <- attributes[:authorized_policy_command?] == true,
         sanitized when is_map(sanitized) <- attributes[:sanitized_representation],
         false <- contains_guidance_payload?(sanitized) do
      {:ok,
       %{
         revision: @revision,
         procedure_iri: procedure.iri,
         policy_iri: attributes.policy_iri,
         representation: sanitized,
         authorized_command_iri: attributes[:command_iri],
         executable?: true
       }}
    else
      _invalid -> {:error, Error.new(:unauthorized, :procedure_policy_boundary)}
    end
  end

  def sanitized_policy(_, _, _),
    do: {:error, Error.new(:unauthorized, :procedure_policy_boundary)}

  defp contains_guidance_payload?(value) do
    value
    |> inspect(limit: :infinity, printable_limit: :infinity)
    |> String.match?(~r/(?:steps|prompt|instruction|procedure)/i)
  end
end
