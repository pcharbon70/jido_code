defmodule JidoCode.Factory.ManagedCoding.CandidateClosureResult do
  @moduledoc "Closed candidate-assembly result that does not coerce incomplete work into success."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CandidateManifest
  alias JidoCode.Factory.ManagedCoding.Identity

  @statuses ~w[ready empty partial conflicting oversized policy_blocked capture_failed]a
  @reasons ~w[none no_changes incomplete_capture conflicting_capture changed_file_limit diff_byte_limit path_scope file_mode binary_policy forbidden_content secret_scan untracked_material capture_unavailable immutable_store_conflict]a
  @enforce_keys [:status, :reason, :evidence_iris]
  defstruct @enforce_keys ++ [:manifest]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with status when status in @statuses <- attributes[:status],
         reason when reason in @reasons <- attributes[:reason],
         :ok <- manifest_contract(status, attributes[:manifest]),
         evidence when is_list(evidence) and length(evidence) <= 64 <- attributes[:evidence_iris],
         true <- Enum.all?(evidence, &(Identity.validate_resource(&1) == :ok)) do
      {:ok,
       %__MODULE__{
         status: status,
         reason: reason,
         manifest: attributes[:manifest],
         evidence_iris: Enum.sort(Enum.uniq(evidence))
       }}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_candidate_result)}
    end
  end

  def new(_attributes),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_candidate_result)}

  defp manifest_contract(:ready, %CandidateManifest{}), do: :ok
  defp manifest_contract(status, nil) when status != :ready, do: :ok
  defp manifest_contract(_status, _manifest), do: :error
end
