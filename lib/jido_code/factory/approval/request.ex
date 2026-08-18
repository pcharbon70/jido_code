defmodule JidoCode.Factory.Approval.Request do
  @moduledoc """
  A single-use human approval bound to one immutable semantic invocation.

  The accepted graph `ApprovalRequest` remains the durable review resource.
  This factory contract retains the normalized material whose digest that
  resource signs, so substitutions are rejected immediately before effect.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @enforce_keys [
    :knowledge_request,
    :action_digest,
    :action,
    :arguments,
    :attempt_iri,
    :invocation_iri,
    :lease_iri,
    :fencing_token,
    :base_revision,
    :patch_digest,
    :artifact_digests,
    :tool_version,
    :model_version,
    :sandbox_version,
    :policy_revision,
    :context_version,
    :capability_iri,
    :external_destination,
    :destination_digest,
    :egress,
    :evidence_iris,
    :reversibility,
    :approver_iri,
    :delegated_scope_iri,
    :execution_actor_iri,
    :separation_required?,
    :approver_authorization_revision,
    :approver_revocation_generation,
    :idempotency,
    :idempotency_key_digest,
    :expires_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @digest ~r/^[a-f0-9]{64}$/
  @reversibility ~w[reversible compensating irreversible]a
  @idempotency ~w[proven unproven]a
  @max_payload_bytes 65_536

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    resources = ~w[
      attempt_iri invocation_iri lease_iri capability_iri approver_iri delegated_scope_iri
      execution_actor_iri
    ]a

    with true <- Enum.all?(resources, &resource?(attributes[&1])),
         true <- text?(attributes[:action], 160),
         {:ok, arguments} <- safe_map(attributes[:arguments]),
         true <- positive_integer?(attributes[:fencing_token]),
         true <- text?(attributes[:base_revision], 256),
         :ok <- digest_value(attributes[:patch_digest]),
         {:ok, artifact_digests} <- digests(attributes[:artifact_digests]),
         :ok <- versions(attributes),
         {:ok, destination} <- safe_map(attributes[:external_destination]),
         true <- map_size(destination) > 0,
         {:ok, egress} <- egress(attributes[:egress]),
         {:ok, evidence_iris} <- resource_list(attributes[:evidence_iris]),
         reversibility when reversibility in @reversibility <- attributes[:reversibility],
         separation? when is_boolean(separation?) <- attributes[:separation_required?],
         true <- not separation? or attributes[:approver_iri] != attributes[:execution_actor_iri],
         true <- non_negative_integer?(attributes[:approver_authorization_revision]),
         true <- non_negative_integer?(attributes[:approver_revocation_generation]),
         idempotency when idempotency in @idempotency <- attributes[:idempotency],
         :ok <- digest_value(attributes[:idempotency_key_digest]),
         %DateTime{} = expires_at <- attributes[:expires_at],
         destination_digest <- digest(destination),
         normalized <-
           normalized(
             attributes,
             arguments,
             artifact_digests,
             destination,
             destination_digest,
             egress,
             evidence_iris,
             expires_at
           ),
         action_digest <- digest(normalized),
         {:ok, knowledge_request} <-
           Knowledge.approval_request(%{
             action_digest: action_digest,
             approver_iri: attributes.approver_iri,
             expires_at: expires_at,
             evidence_iris: evidence_iris
           }) do
      {:ok,
       normalized
       |> Map.put(:knowledge_request, knowledge_request)
       |> Map.put(:action_digest, action_digest)
       |> then(&struct!(__MODULE__, &1))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      {:error, _knowledge_error} -> invalid(:approval_request)
      _invalid -> invalid(:approval_request)
    end
  rescue
    _error -> invalid(:approval_request)
  end

  def new(_attributes), do: invalid(:approval_request)

  @spec digest_valid?(t()) :: boolean()
  def digest_valid?(%__MODULE__{} = request) do
    request.action_digest ==
      request
      |> Map.from_struct()
      |> Map.drop([:knowledge_request, :action_digest])
      |> digest()
  end

  @spec approval_iri(t()) :: String.t()
  def approval_iri(%__MODULE__{knowledge_request: request}), do: request.iri

  defp normalized(
         attributes,
         arguments,
         artifact_digests,
         destination,
         destination_digest,
         egress,
         evidence_iris,
         expires_at
       ) do
    attributes
    |> Map.take(@enforce_keys)
    |> Map.put(:arguments, arguments)
    |> Map.put(:artifact_digests, artifact_digests)
    |> Map.put(:external_destination, destination)
    |> Map.put(:destination_digest, destination_digest)
    |> Map.put(:egress, egress)
    |> Map.put(:evidence_iris, evidence_iris)
    |> Map.put(:expires_at, DateTime.truncate(expires_at, :microsecond))
    |> Map.drop([:knowledge_request, :action_digest])
  end

  defp versions(attributes) do
    if Enum.all?(
         [:tool_version, :model_version, :sandbox_version, :policy_revision, :context_version],
         &text?(attributes[&1], 256)
       ),
       do: :ok,
       else: invalid(:approval_versions)
  end

  defp egress(%{digest: digest, byte_count: byte_count, classification: classification})
       when is_integer(byte_count) and byte_count >= 0 and byte_count <= 100_000_000 and
              classification in [:public, :internal, :confidential, :restricted] do
    with :ok <- digest_value(digest) do
      {:ok, %{digest: digest, byte_count: byte_count, classification: classification}}
    end
  end

  defp egress(_egress), do: invalid(:approval_egress)

  defp digests(values) when is_list(values) and values != [] and length(values) <= 100 do
    values = values |> Enum.uniq() |> Enum.sort()

    if Enum.all?(values, &(digest_value(&1) == :ok)),
      do: {:ok, values},
      else: invalid(:approval_digests)
  end

  defp digests(_values), do: invalid(:approval_digests)

  defp resource_list(values) when is_list(values) and values != [] and length(values) <= 100 do
    values = values |> Enum.uniq() |> Enum.sort()
    if Enum.all?(values, &resource?/1), do: {:ok, values}, else: invalid(:approval_evidence)
  end

  defp resource_list(_values), do: invalid(:approval_evidence)

  defp safe_map(value) when is_map(value) and map_size(value) <= 64 do
    if safe_value?(value) and bounded?(value), do: {:ok, value}, else: invalid(:approval_payload)
  end

  defp safe_map(_value), do: invalid(:approval_payload)

  defp safe_value?(value) when is_map(value) do
    Enum.all?(value, fn {key, item} -> safe_key?(key) and safe_value?(item) end)
  end

  defp safe_value?(value) when is_list(value) and length(value) <= 100,
    do: Enum.all?(value, &safe_value?/1)

  defp safe_value?(value) when is_binary(value), do: text?(value, 4_096)
  defp safe_value?(value) when is_atom(value) or is_integer(value) or is_boolean(value), do: true
  defp safe_value?(nil), do: true
  defp safe_value?(_value), do: false

  defp safe_key?(key) when is_atom(key), do: true
  defp safe_key?(key) when is_binary(key), do: text?(key, 160)
  defp safe_key?(_key), do: false

  defp bounded?(value),
    do:
      value
      |> :erlang.term_to_binary([:deterministic])
      |> byte_size()
      |> Kernel.<=(@max_payload_bytes)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp digest_value(value) when is_binary(value) do
    if Regex.match?(@digest, value), do: :ok, else: invalid(:approval_digest)
  end

  defp digest_value(_value), do: invalid(:approval_digest)
  defp resource?(value), do: Knowledge.validate_resource_identity(value) == :ok
  defp positive_integer?(value), do: is_integer(value) and value > 0
  defp non_negative_integer?(value), do: is_integer(value) and value >= 0

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
