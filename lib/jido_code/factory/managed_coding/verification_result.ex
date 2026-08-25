defmodule JidoCode.Factory.ManagedCoding.VerificationResult do
  @moduledoc "Attributable verifier result bound to exact candidate, environment, and evidence."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.VerificationRequest

  @statuses ~w[passed failed indeterminate expired unavailable timeout]a
  @check_statuses ~w[passed failed skipped timeout unavailable indeterminate]a
  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys ~w[verification_iri candidate_iri candidate_digest verifier_actor_iri verifier_profile_revision environment_revision toolchain_revision policy_revision status checks evidence_iris evidence_digest completed_at acceptance_authority publication_authority]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(VerificationRequest.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%VerificationRequest{} = request, attributes) when is_map(attributes) do
    with status when status in @statuses <- attributes[:status],
         {:ok, checks} <- checks(attributes[:checks], request),
         {:ok, evidence} <- evidence(attributes[:evidence_iris]),
         true <- digest?(attributes[:evidence_digest]),
         %DateTime{} = completed_at <- attributes[:completed_at],
         true <-
           DateTime.compare(completed_at, request.deadline) in [:lt, :eq] or status == :expired,
         true <- attributes[:candidate_digest] == request.candidate_digest,
         true <- attributes[:verifier_profile_revision] == request.verifier_profile_revision,
         true <- attributes[:environment_revision] == request.environment_revision,
         true <- attributes[:toolchain_revision] == request.toolchain_revision,
         true <- attributes[:policy_revision] == request.policy_revision,
         true <- coherent_status?(status, checks) do
      {:ok,
       %__MODULE__{
         verification_iri: request.verification_iri,
         candidate_iri: request.candidate_iri,
         candidate_digest: request.candidate_digest,
         verifier_actor_iri: request.verifier_actor_iri,
         verifier_profile_revision: request.verifier_profile_revision,
         environment_revision: request.environment_revision,
         toolchain_revision: request.toolchain_revision,
         policy_revision: request.policy_revision,
         status: status,
         checks: checks,
         evidence_iris: evidence,
         evidence_digest: attributes.evidence_digest,
         completed_at: DateTime.truncate(completed_at, :microsecond),
         acceptance_authority: false,
         publication_authority: false
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_request, _attributes), do: invalid()

  defp checks(values, request)
       when is_list(values) and length(values) == length(request.checks) do
    expected = Enum.map(request.checks, & &1.id) |> Enum.sort()

    valid =
      Enum.all?(values, fn
        %{
          id: id,
          status: status,
          result_digest: result,
          log_artifact_iri: log,
          resource_observation_iri: resource
        } ->
          is_binary(id) and status in @check_statuses and digest?(result) and
            Identity.validate_resource(log) == :ok and Identity.validate_resource(resource) == :ok

        _invalid ->
          false
      end)

    if valid and Enum.map(values, & &1.id) |> Enum.sort() == expected,
      do: {:ok, Enum.sort_by(values, & &1.id)},
      else: :error
  end

  defp checks(_values, _request), do: :error

  defp evidence(values) when is_list(values) and values != [] and length(values) <= 128 do
    if Enum.all?(values, &(Identity.validate_resource(&1) == :ok)),
      do: {:ok, Enum.sort(Enum.uniq(values))},
      else: :error
  end

  defp evidence(_values), do: :error

  defp coherent_status?(:passed, checks), do: Enum.all?(checks, &(&1.status == :passed))
  defp coherent_status?(:failed, checks), do: Enum.any?(checks, &(&1.status == :failed))

  defp coherent_status?(:indeterminate, checks),
    do: Enum.any?(checks, &(&1.status in [:indeterminate, :unavailable, :skipped]))

  defp coherent_status?(:unavailable, checks), do: Enum.any?(checks, &(&1.status == :unavailable))
  defp coherent_status?(:timeout, checks), do: Enum.any?(checks, &(&1.status == :timeout))
  defp coherent_status?(:expired, _checks), do: true

  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp invalid,
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_verification_result)}
end
