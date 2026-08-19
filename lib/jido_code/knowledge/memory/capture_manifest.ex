defmodule JidoCode.Knowledge.Memory.CaptureManifest do
  @moduledoc """
  Episode-level contract for exact expected-body accounting.

  The manifest is created atomically with a segmented attempt. Expected body
  identities are deterministic and opaque; closure succeeds only when every
  expected body has exactly one capture shell and no unlisted shell exists.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.Memory.ContentCapture
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @enforce_keys [
    :iri,
    :attempt_iri,
    :profile,
    :purpose,
    :policy_revision,
    :expected_event_classes,
    :expected_body_classes,
    :expected_bodies,
    :limits,
    :expected_root_digest
  ]
  defstruct @enforce_keys ++ [:completeness_root_digest]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_entity "http://www.w3.org/ns/prov#Entity"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @protocol "2.0.0"
  @body_roles ~w[instruction input output diagnostic artifact message]a
  @body_classes ~w[
    instruction_content interaction_message model_outcome tool_stdout_stderr embedded_artifact
  ]a
  @event_classes EventSegment.event_types()

  @spec revision() :: String.t()
  def revision, do: @protocol

  @spec body_roles() :: [atom()]
  def body_roles, do: @body_roles

  @spec body_classes() :: [atom()]
  def body_classes, do: @body_classes

  @spec new(String.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attempt_iri, attributes) when is_map(attributes) do
    profile = attributes[:profile]
    purpose = attributes[:purpose]
    policy_revision = attributes[:policy_revision]
    event_classes = attributes[:expected_event_classes]
    body_classes = attributes[:expected_body_classes]
    body_specs = attributes[:expected_bodies]
    limits = attributes[:limits]

    with :ok <- ResourceIdentity.validate(attempt_iri),
         true <- DataPolicy.profile_enabled?(profile),
         {:ok, %{purpose: ^purpose}} <- DataPolicy.profile(profile),
         true <- policy_revision == DataPolicy.revision(),
         :ok <- exact_atoms(event_classes, @event_classes, :capture_event_classes),
         :ok <- exact_atoms(body_classes, @body_classes, :capture_body_classes),
         {:ok, bodies} <- normalize_bodies(attempt_iri, body_specs, event_classes, body_classes),
         :ok <- validate_limits(limits, length(bodies)),
         {:ok, iri} <- ResourceIdentity.deterministic(:capture_manifest, attempt_iri),
         expected_root = expected_root(bodies, profile, purpose, policy_revision, limits) do
      {:ok,
       %__MODULE__{
         iri: iri,
         attempt_iri: attempt_iri,
         profile: profile,
         purpose: purpose,
         policy_revision: policy_revision,
         expected_event_classes: Enum.sort(event_classes),
         expected_body_classes: Enum.sort(body_classes),
         expected_bodies: bodies,
         limits: limits,
         expected_root_digest: expected_root,
         completeness_root_digest: nil
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:capture_manifest)
    end
  rescue
    _error -> invalid(:capture_manifest)
  end

  def new(_attempt_iri, _attributes), do: invalid(:capture_manifest)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = manifest) do
    [
      {manifest.iri, @rdf_type, RDF.iri(@jf <> "CaptureManifest")},
      {manifest.iri, @jf <> "about", RDF.iri(manifest.attempt_iri)},
      {manifest.iri, @jf <> "memoryProtocolVersion", RDF.XSD.String.new(@protocol)},
      {manifest.iri, @jf <> "captureProfile",
       RDF.iri(@concept <> Macro.camelize(to_string(manifest.profile)))},
      {manifest.iri, @jf <> "capturePolicyRevision",
       RDF.XSD.String.new(manifest.policy_revision)},
      {manifest.iri, @jf <> "capturePurpose", RDF.XSD.String.new(to_string(manifest.purpose))},
      {manifest.iri, @jf <> "expectedRootDigest",
       RDF.XSD.String.new(manifest.expected_root_digest)},
      {manifest.iri, @jf <> "captureLimitsDigest",
       RDF.XSD.String.new(digest_term(manifest.limits))}
    ] ++
      Enum.map(manifest.expected_event_classes, fn class ->
        {manifest.iri, @jf <> "expectedEventClass", RDF.XSD.String.new(to_string(class))}
      end) ++
      Enum.map(manifest.expected_body_classes, fn class ->
        {manifest.iri, @jf <> "expectedBodyClass", RDF.XSD.String.new(to_string(class))}
      end) ++
      Enum.flat_map(manifest.expected_bodies, &body_statements(manifest.iri, &1))
  end

  @spec attach_to_run_targets(t(), [map()]) :: {:ok, [map()]} | {:error, Error.t()}
  def attach_to_run_targets(%__MODULE__{} = manifest, targets) when is_list(targets) do
    run_targets = Enum.count(targets, &match?(%{family: :run_attempt, operation: :create}, &1))

    if run_targets == 1 do
      {:ok,
       Enum.map(targets, fn
         %{family: :run_attempt, operation: :create, additions: additions} = target ->
           %{target | additions: additions ++ statements(manifest)}

         target ->
           target
       end)}
    else
      invalid(:capture_manifest_run_target)
    end
  end

  def attach_to_run_targets(_manifest, _targets), do: invalid(:capture_manifest_run_target)

  @spec close(t(), [ContentCapture.t()]) :: {:ok, t()} | {:error, Error.t()}
  def close(%__MODULE__{completeness_root_digest: nil} = manifest, captures)
      when is_list(captures) do
    expected = Enum.map(manifest.expected_bodies, & &1.iri) |> Enum.sort()

    with true <- Enum.all?(captures, &match?(%ContentCapture{}, &1)),
         true <- Enum.all?(captures, &(&1.manifest_iri == manifest.iri)),
         actual = Enum.map(captures, & &1.body_iri),
         true <- length(actual) == length(Enum.uniq(actual)),
         true <- Enum.sort(actual) == expected do
      root =
        captures
        |> Enum.sort_by(& &1.body_iri)
        |> Enum.map(fn capture ->
          {capture.body_iri, capture.iri, capture.capture_outcome, capture.representation,
           capture.storage_location, capture.availability, capture.retention, capture.hold}
        end)
        |> then(&digest_term({manifest.expected_root_digest, &1}))

      {:ok, %{manifest | completeness_root_digest: root}}
    else
      _invalid -> conflict(:capture_manifest_incomplete)
    end
  end

  def close(%__MODULE__{}, _captures), do: conflict(:capture_manifest_closed)
  def close(_manifest, _captures), do: invalid(:capture_manifest_close)

  @spec closure_statements(t()) :: [tuple()]
  def closure_statements(%__MODULE__{completeness_root_digest: root} = manifest)
      when is_binary(root) do
    [
      {manifest.iri, @jf <> "completenessRootDigest", RDF.XSD.String.new(root)},
      {manifest.iri, @jf <> "captureCompleteness", RDF.iri(@concept <> "Complete")}
    ]
  end

  def closure_statements(_manifest), do: []

  @spec body(t(), String.t()) :: {:ok, map()} | :error
  def body(%__MODULE__{} = manifest, body_iri) do
    case Enum.find(manifest.expected_bodies, &(&1.iri == body_iri)) do
      nil -> :error
      body -> {:ok, body}
    end
  end

  defp normalize_bodies(attempt_iri, specs, event_classes, body_classes)
       when is_list(specs) and specs != [] and length(specs) <= 100 do
    normalized = Enum.map(specs, &normalize_body(attempt_iri, &1, event_classes, body_classes))

    if Enum.all?(normalized, &match?({:ok, _}, &1)) do
      bodies = normalized |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.iri)

      if length(bodies) == length(Enum.uniq_by(bodies, & &1.iri)),
        do: {:ok, bodies},
        else: conflict(:duplicate_expected_body)
    else
      invalid(:expected_body)
    end
  end

  defp normalize_bodies(_attempt, _specs, _events, _bodies), do: invalid(:expected_body)

  defp normalize_body(attempt_iri, spec, event_classes, body_classes) when is_map(spec) do
    with :ok <- ResourceIdentity.validate(spec[:event_iri]),
         true <- spec[:event_class] in event_classes,
         true <- spec[:body_class] in body_classes,
         true <- spec[:role] in @body_roles,
         identity when is_binary(identity) <- spec[:content_identity],
         true <- Regex.match?(~r/^[a-f0-9]{64}$/, identity),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :content_body,
             Enum.join([attempt_iri, spec.event_iri, spec.role, identity], "\n")
           ) do
      {:ok,
       %{
         iri: iri,
         event_iri: spec.event_iri,
         event_class: spec.event_class,
         body_class: spec.body_class,
         role: spec.role,
         content_identity: identity
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:expected_body)
    end
  end

  defp normalize_body(_attempt, _spec, _events, _bodies), do: invalid(:expected_body)

  defp body_statements(manifest_iri, body) do
    [
      {manifest_iri, @jf <> "expectedBody", RDF.iri(body.iri)},
      {body.iri, @rdf_type, RDF.iri(@prov_entity)},
      {body.iri, @jf <> "sourceEvent", RDF.iri(body.event_iri)},
      {body.iri, @jf <> "eventKind", RDF.XSD.String.new(to_string(body.event_class))},
      {body.iri, @jf <> "bodyClass", RDF.XSD.String.new(to_string(body.body_class))},
      {body.iri, @jf <> "bodyRole", RDF.XSD.String.new(to_string(body.role))},
      {body.iri, @jf <> "opaqueContentIdentity", RDF.XSD.String.new(body.content_identity)}
    ]
  end

  defp expected_root(bodies, profile, purpose, policy_revision, limits) do
    material =
      Enum.map(bodies, fn body ->
        {body.iri, body.event_iri, body.event_class, body.body_class, body.role,
         body.content_identity}
      end)

    digest_term({@protocol, profile, purpose, policy_revision, limits, material})
  end

  defp validate_limits(limits, body_count) when is_map(limits) do
    capacity = Guardrails.capacity_profile()

    if limits[:expected_body_limit] == body_count and body_count <= 100 and
         limits[:segment_event_limit] == capacity.segment_event_limit and
         limits[:segment_count_limit] == capacity.segment_count_limit,
       do: :ok,
       else: invalid(:capture_limits)
  end

  defp validate_limits(_limits, _body_count), do: invalid(:capture_limits)

  defp exact_atoms(values, allowed, operation) when is_list(values) and values != [] do
    if length(values) == length(Enum.uniq(values)) and Enum.all?(values, &(&1 in allowed)),
      do: :ok,
      else: invalid(operation)
  end

  defp exact_atoms(_values, _allowed, operation), do: invalid(operation)

  defp digest_term(term) do
    term
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, Error.new(:conflict, operation)}
end
