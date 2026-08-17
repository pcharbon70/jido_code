defmodule JidoCode.Factory.Tool.Definition do
  @moduledoc "Closed model-facing tool contract with pinned supply-chain metadata."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @derive {Inspect, only: [:name, :version, :capability, :effect_class]}
  @enforce_keys [
    :iri,
    :name,
    :version,
    :description,
    :input_schema,
    :input_schema_digest,
    :output_schema,
    :output_schema_digest,
    :capability,
    :effect_class,
    :preconditions,
    :side_effects,
    :reversibility,
    :timeout_ms,
    :retry_policy,
    :idempotency_policy,
    :max_output_bytes,
    :approval_required,
    :adapter_identity,
    :adapter_digest,
    :network_policy,
    :safe_errors
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @name ~r/^[a-z][a-z0-9_]*$/
  @version ~r/^[0-9]+\.[0-9]+\.[0-9]+$/
  @digest ~r/^sha256:[a-f0-9]{64}$/
  @effect_classes ~w[read write external publish]a
  @reversibility ~w[none compensating reversible not_applicable]a
  @retry_policies ~w[never safe_idempotent reconcile_first]a
  @idempotency_policies ~w[read_only required external_effect_id]a
  @safe_errors ~w[
    invalid_input unauthorized conflict unavailable timeout corrupt approval_required
  ]a

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with name when is_binary(name) and byte_size(name) in 1..64 <- attributes[:name],
         true <- Regex.match?(@name, name),
         version when is_binary(version) and byte_size(version) in 1..32 <-
           attributes[:version],
         true <- Regex.match?(@version, version),
         description when is_binary(description) and byte_size(description) in 1..512 <-
           attributes[:description],
         input_schema when is_map(input_schema) <- attributes[:input_schema],
         output_schema when is_map(output_schema) <- attributes[:output_schema],
         true <- bounded?(input_schema, 16_384) and bounded?(output_schema, 16_384),
         true <- digest?(attributes[:input_schema_digest]),
         true <- digest?(attributes[:output_schema_digest]),
         true <- attributes.input_schema_digest == digest(input_schema),
         true <- attributes.output_schema_digest == digest(output_schema),
         capability when is_atom(capability) <- attributes[:capability],
         effect_class when effect_class in @effect_classes <- attributes[:effect_class],
         true <- atom_list?(attributes[:preconditions], 16),
         true <- atom_list?(attributes[:side_effects], 16),
         reversibility when reversibility in @reversibility <- attributes[:reversibility],
         timeout when is_integer(timeout) and timeout in 100..300_000 <- attributes[:timeout_ms],
         retry_policy when retry_policy in @retry_policies <- attributes[:retry_policy],
         idempotency_policy when idempotency_policy in @idempotency_policies <-
           attributes[:idempotency_policy],
         maximum when is_integer(maximum) and maximum in 1..1_048_576 <-
           attributes[:max_output_bytes],
         approval when is_boolean(approval) <- attributes[:approval_required],
         adapter when is_binary(adapter) and byte_size(adapter) in 1..160 <-
           attributes[:adapter_identity],
         true <- Regex.match?(~r/^[A-Za-z0-9_.:\/-]+$/, adapter),
         true <- digest?(attributes[:adapter_digest]),
         true <- attributes.adapter_digest == digest(adapter),
         :ok <- network_policy(attributes[:network_policy]),
         true <- safe_errors?(attributes[:safe_errors]),
         {:ok, %{iri: iri}} <-
           Knowledge.tool_definition(%{
             tool_name: name,
             tool_version: version,
             input_schema_digest: attributes.input_schema_digest,
             output_schema_digest: attributes.output_schema_digest,
             effect_class: effect_class,
             adapter_digest: attributes.adapter_digest,
             approval_required: approval,
             timeout_ms: timeout
           }) do
      {:ok,
       %__MODULE__{
         iri: iri,
         name: name,
         version: version,
         description: description,
         input_schema: input_schema,
         input_schema_digest: attributes.input_schema_digest,
         output_schema: output_schema,
         output_schema_digest: attributes.output_schema_digest,
         capability: capability,
         effect_class: effect_class,
         preconditions: Enum.sort(attributes.preconditions),
         side_effects: Enum.sort(attributes.side_effects),
         reversibility: reversibility,
         timeout_ms: timeout,
         retry_policy: retry_policy,
         idempotency_policy: idempotency_policy,
         max_output_bytes: maximum,
         approval_required: approval,
         adapter_identity: adapter,
         adapter_digest: attributes.adapter_digest,
         network_policy: attributes.network_policy,
         safe_errors: Enum.sort(attributes.safe_errors)
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec digest(term()) :: String.t()
  def digest(value) do
    "sha256:" <>
      (:crypto.hash(:sha256, :erlang.term_to_binary(value, [:deterministic]))
       |> Base.encode16(case: :lower))
  end

  defp atom_list?(values, maximum) when is_list(values) and length(values) <= maximum,
    do: Enum.all?(values, &is_atom/1) and length(values) == length(Enum.uniq(values))

  defp atom_list?(_values, _maximum), do: false

  defp safe_errors?(values) when is_list(values) and values != [] do
    Enum.all?(values, &(&1 in @safe_errors)) and length(values) == length(Enum.uniq(values))
  end

  defp safe_errors?(_values), do: false

  defp network_policy(:deny), do: :ok

  defp network_policy({:allowlist, destinations})
       when is_list(destinations) and destinations != [] and length(destinations) <= 16 do
    if Enum.all?(destinations, &(is_binary(&1) and byte_size(&1) in 1..256)),
      do: :ok,
      else: :error
  end

  defp network_policy(_policy), do: :error
  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp bounded?(value, maximum),
    do: byte_size(:erlang.term_to_binary(value, [:deterministic])) <= maximum

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :tool_definition)}
end
