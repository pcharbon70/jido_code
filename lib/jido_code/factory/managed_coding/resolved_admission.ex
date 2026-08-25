defmodule JidoCode.Factory.ManagedCoding.ResolvedAdmission do
  @moduledoc "Exact authority and revision projection required before admitting managed coding."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Budget
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.Profile

  @resources ~w[
    attempt_iri lease_iri tenant_iri repository_iri task_iri actor_iri policy_iri
    snapshot_iri credential_reference_iri capability_iri admission_evidence_iri
  ]a
  @digests ~w[policy_revision snapshot_revision credential_revision capability_revision]a
  @enforce_keys @resources ++ @digests ++ [:fencing_token, :profile, :budget, :resolved_at]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @digest ~r/^[a-f0-9]{64}$/

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- Enum.all?(@resources, &(Identity.validate_resource(attributes[&1]) == :ok)),
         true <- Enum.all?(@digests, &digest?(attributes[&1])),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         %Profile{} = profile <- attributes[:profile],
         %Budget{} = budget <- attributes[:budget],
         true <- budget == profile.budget,
         %DateTime{} <- attributes[:resolved_at] do
      {:ok, struct!(__MODULE__, Map.take(attributes, @enforce_keys))}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()
  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_resolved_admission)}
end
