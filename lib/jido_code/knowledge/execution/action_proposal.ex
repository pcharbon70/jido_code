defmodule JidoCode.Knowledge.Execution.ActionProposal do
  @moduledoc """
  Classified model-requested effect proposals.

  An action proposal captures what a model asked for - tool command name,
  proposal digest, and arguments digest - without persisting raw
  secret-bearing arguments. A proposal is never effect authority; the
  reference monitor authorizes the normalized effect separately.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [:iri, :invocation_iri, :proposed_command, :proposal_digest, :arguments_digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"
  @digest64 ~r/^[a-f0-9]{64}$/
  @command_format ~r/^[a-z][a-z0-9_.]*$/

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:invocation_iri]),
         command when is_binary(command) and byte_size(command) in 1..64 <-
           attributes[:proposed_command],
         true <- Regex.match?(@command_format, command),
         true <- digest64?(attributes[:proposal_digest]),
         true <- digest64?(attributes[:arguments_digest]),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :action_proposal,
             attributes.invocation_iri <> "\n" <> attributes.proposal_digest
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         invocation_iri: attributes.invocation_iri,
         proposed_command: command,
         proposal_digest: attributes.proposal_digest,
         arguments_digest: attributes.arguments_digest
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:action_proposal)
    end
  rescue
    _error -> invalid(:action_proposal)
  end

  def new(_attributes), do: invalid(:action_proposal)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = proposal) do
    [
      {proposal.iri, @rdf_type, RDF.iri(@jf <> "ActionProposal")},
      {proposal.iri, @jf <> "proposalOf", RDF.iri(proposal.invocation_iri)},
      {proposal.iri, @jf <> "proposedCommand", RDF.XSD.String.new(proposal.proposed_command)},
      {proposal.iri, @jf <> "proposalDigest", RDF.XSD.String.new(proposal.proposal_digest)},
      {proposal.iri, @jf <> "proposalArgumentsDigest",
       RDF.XSD.String.new(proposal.arguments_digest)}
    ]
  end

  defp digest64?(value), do: is_binary(value) and Regex.match?(@digest64, value)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
