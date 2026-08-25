defmodule JidoCode.Factory.ManagedCoding.PublicationHandoff do
  @moduledoc "Non-effectful handoff from accepted disposition to separately authorized publication."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Disposition
  alias JidoCode.Factory.ManagedCoding.Identity

  @enforce_keys ~w[candidate_iri disposition_iri publication_workflow_iri requested_by_iri status human_merge_required branch_push_authority pull_request_authority approval_authority merge_authority]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Disposition.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%Disposition{decision: :accepted} = disposition, attributes) when is_map(attributes) do
    with :ok <- Identity.validate_resource(attributes[:publication_workflow_iri]),
         :ok <- Identity.validate_resource(attributes[:requested_by_iri]),
         true <- attributes[:human_merge_required] == true do
      {:ok,
       %__MODULE__{
         candidate_iri: disposition.candidate_iri,
         disposition_iri: disposition.disposition_iri,
         publication_workflow_iri: attributes.publication_workflow_iri,
         requested_by_iri: attributes.requested_by_iri,
         status: :human_merge_required,
         human_merge_required: true,
         branch_push_authority: false,
         pull_request_authority: false,
         approval_authority: false,
         merge_authority: false
       }}
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :managed_coding_publication_handoff)}
    end
  end

  def new(_disposition, _attributes),
    do: {:error, AdapterError.new(:unauthorized, :managed_coding_publication_handoff)}
end
