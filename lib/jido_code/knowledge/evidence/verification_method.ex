defmodule JidoCode.Knowledge.Evidence.VerificationMethod do
  @moduledoc "Versioned, bounded contract describing what a verification can establish."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :name,
    :kind,
    :version,
    :input_classes,
    :expected_claim_iris,
    :requires_complete?,
    :evaluator_capability_iri,
    :environment,
    :bounds,
    :interpretation_limits,
    :independent_evaluator?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @kinds ~w[
    test_execution static_analysis semantic_comparison human_review policy_check security_review
    external_provider_confirmation
  ]a
  @input_classes ~w[source_snapshot proposed_snapshot post_change_snapshot artifact attempt claim goal]a
  @supported_versions ["1.0.0"]
  @required_bounds ~w[max_duration_ms max_artifacts max_checks]a

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with {:ok, name} <- text(attributes[:name], 120),
         kind when kind in @kinds <- attributes[:kind],
         version when version in @supported_versions <- attributes[:version],
         {:ok, input_classes} <- input_classes(attributes[:input_classes]),
         {:ok, expected_claim_iris} <- resources(attributes[:expected_claim_iris], 100, true),
         requires_complete? when is_boolean(requires_complete?) <-
           attributes[:requires_complete?],
         :ok <- ResourceIdentity.validate(attributes[:evaluator_capability_iri]),
         {:ok, environment} <- bounded_map(attributes[:environment], 12),
         {:ok, bounds} <- bounds(attributes[:bounds]),
         {:ok, limits} <- texts(attributes[:interpretation_limits], 20, 512),
         independent? when is_boolean(independent?) <- attributes[:independent_evaluator?],
         {:ok, iri} <- identity(name, kind, version, attributes) do
      {:ok,
       %__MODULE__{
         iri: iri,
         name: name,
         kind: kind,
         version: version,
         input_classes: input_classes,
         expected_claim_iris: expected_claim_iris,
         requires_complete?: requires_complete?,
         evaluator_capability_iri: attributes[:evaluator_capability_iri],
         environment: environment,
         bounds: bounds,
         interpretation_limits: limits,
         independent_evaluator?: independent?
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:verification_method)
    end
  rescue
    _error -> invalid(:verification_method)
  end

  def new(_attributes), do: invalid(:verification_method)

  @spec kinds() :: [atom()]
  def kinds, do: @kinds

  @spec supported?(atom(), String.t()) :: boolean()
  def supported?(kind, version), do: kind in @kinds and version in @supported_versions

  @spec statements(t()) :: [RDF.Triple.t()]
  def statements(%__MODULE__{} = method) do
    jf = "https://jido.run/ontology/factory#"
    rdf_type = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
    concept = "https://jido.run/ontology/concept/"

    [
      {method.iri, rdf_type, RDF.iri(jf <> "VerificationMethod")},
      {method.iri, jf <> "displayId", RDF.XSD.String.new(method.name)},
      {method.iri, jf <> "verificationKind",
       RDF.iri(concept <> Macro.camelize(to_string(method.kind)))},
      {method.iri, jf <> "version", RDF.XSD.String.new(method.version)},
      {method.iri, jf <> "evaluatorCapability", RDF.iri(method.evaluator_capability_iri)},
      {method.iri, jf <> "requiresComplete", RDF.XSD.Boolean.new(method.requires_complete?)},
      {method.iri, jf <> "independentEvaluation",
       RDF.XSD.Boolean.new(method.independent_evaluator?)},
      {method.iri, jf <> "environmentDigest", RDF.XSD.String.new(digest(method.environment))},
      {method.iri, jf <> "boundPayload", RDF.XSD.String.new(Jason.encode!(method.bounds))}
    ] ++
      Enum.map(method.input_classes, fn input_class ->
        {method.iri, jf <> "inputClass",
         RDF.iri(concept <> Macro.camelize(to_string(input_class)))}
      end) ++
      Enum.map(method.expected_claim_iris, fn claim ->
        {method.iri, jf <> "expectedClaim", RDF.iri(claim)}
      end) ++
      Enum.map(method.interpretation_limits, fn limitation ->
        {method.iri, jf <> "limitation", RDF.XSD.String.new(limitation)}
      end)
  end

  defp identity(name, kind, version, attributes) do
    material =
      {
        name,
        kind,
        version,
        Enum.sort(attributes.input_classes),
        Enum.sort(attributes.expected_claim_iris),
        attributes.evaluator_capability_iri,
        attributes.environment,
        attributes.bounds,
        attributes.interpretation_limits,
        attributes.requires_complete?,
        attributes.independent_evaluator?
      }
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    ResourceIdentity.deterministic(:verification_method, material)
  end

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp input_classes(values) when is_list(values) and values != [] and length(values) <= 12 do
    values = Enum.uniq(values)
    if Enum.all?(values, &(&1 in @input_classes)), do: {:ok, Enum.sort(values)}, else: :error
  end

  defp input_classes(_values), do: :error

  defp bounds(value) do
    with {:ok, value} <- bounded_map(value, 8),
         true <- Enum.all?(@required_bounds, &Map.has_key?(value, &1)),
         duration when is_integer(duration) and duration in 1..3_600_000 <- value.max_duration_ms,
         artifacts when is_integer(artifacts) and artifacts in 1..100 <- value.max_artifacts,
         checks when is_integer(checks) and checks in 1..1_000 <- value.max_checks do
      {:ok, value}
    else
      _invalid -> :error
    end
  end

  defp bounded_map(value, maximum)
       when is_map(value) and map_size(value) > 0 and map_size(value) <= maximum do
    if Enum.all?(value, fn {key, item} ->
         is_atom(key) and
           (is_binary(item) or is_integer(item) or is_boolean(item)) and
           safe_scalar?(item)
       end),
       do: {:ok, value},
       else: :error
  end

  defp bounded_map(_value, _maximum), do: :error

  defp resources(values, maximum, required?) when is_list(values) and length(values) <= maximum do
    values = Enum.uniq(values)

    if (not required? or values != []) and
         Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, Enum.sort(values)},
       else: :error
  end

  defp resources(_values, _maximum, _required?), do: :error

  defp texts(values, maximum, bytes) when is_list(values) and length(values) <= maximum do
    case Enum.reduce_while(values, [], fn value, acc ->
           case text(value, bytes) do
             {:ok, normalized} -> {:cont, [normalized | acc]}
             _error -> {:halt, :error}
           end
         end) do
      :error -> :error
      normalized -> {:ok, normalized |> Enum.uniq() |> Enum.sort()}
    end
  end

  defp texts(_values, _maximum, _bytes), do: :error

  defp text(value, maximum) when is_binary(value) do
    normalized = :unicode.characters_to_nfc_binary(value)

    if value == normalized and byte_size(value) in 1..maximum and
         not Regex.match?(~r/[\x00-\x1F\x7F]/u, value),
       do: {:ok, value},
       else: :error
  end

  defp text(_value, _maximum), do: :error
  defp safe_scalar?(value) when is_binary(value), do: byte_size(value) <= 512
  defp safe_scalar?(_value), do: true
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
