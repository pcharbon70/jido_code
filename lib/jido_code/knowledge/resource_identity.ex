defmodule JidoCode.Knowledge.ResourceIdentity do
  @moduledoc """
  Pure construction and validation of canonical product resource IRIs.

  Natural external identities are normalized before construction. Local
  identities use a caller-supplied millisecond timestamp and ten entropy bytes;
  `generate_local/2` is the explicit clock/random port for runtime callers.
  """

  alias JidoCode.Knowledge.Error

  @base "https://jido.run/id/"
  @max_iri_bytes 512
  @max_segment_bytes 160
  @local_kinds ~w[
    activity audit claim command decision delegation goal attempt migration transition
    validation-report validation-result
  ]
  @deterministic_kinds ~w[
    authorization-grant change-set command-request graph-revision-reference validation-report
    validation-result management-enrollment enrollment-transition enrollment-decision
    repository-reconciliation observation-activity observation-batch repository-snapshot
    observed-claim provider-object source-artifact code-symbol source-analysis desired-outcome
    control-constraint control-transition control-decision goal-proposal plan-proposal task-proposal
    plan-adoption policy-version policy-evaluator repository-cohort cohort-membership
    policy-obligation capability-declaration capability-classification reconciliation-package
    reconciliation-activity reconciliation-gap control-proposal eligibility-receipt execution-lease
    execution-attempt execution-context execution-instruction interaction-session
    interaction-message cancellation-request retry-decision
    tool-invocation tool-invocation-event patch-artifact generated-artifact artifact-finding
    sandbox-activity run-completeness verification-method verification-activity verification-check
    evidence-bundle evidence-claim evidence-sufficiency goal-outcome-decision claim-disposition
    decision-follow-up follow-up-goal follow-up-task decision-reconciliation
    knowledge-assertion adoption-activity knowledge-state-transition knowledge-evolution-activity
    reasoning-activity reasoning-validation-report insight-proposal learning-measurement
    model-access-profile model-access-revocation harness-profile tool-definition-revision
    context-manifest model-invocation model-invocation-event action-proposal sandbox-instance
    approval-request event-segment execution-event execution-event-head capture-manifest
    content-body content-capture segment-closure continuation-authority memory-retrieval-request
    memory-retrieval-activity memory-evidence-packet experience-case experience-transition
    experience-source-manifest candidate-fact-or-summary experience-quarantine-report
    memory-use-assessment artifact-claim artifact-claim-transition procedure-revision
    procedure-transition procedure-quarantine-report procedure-use-observation
    episode-content content-chunk content-key-reference content-benchmark-decision
    content-access-permit content-access-activity content-access-outcome
  ]
  @digest_lengths %{"sha1" => 40, "sha256" => 64, "sha512" => 128}
  @max_timestamp 281_474_976_710_655

  @spec base() :: String.t()
  def base, do: @base

  @spec provider_host(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def provider_host(input) when is_binary(input) do
    with {:ok, host} <- normalize_host(input),
         {:ok, segment} <- encode_segment(host) do
      build("provider", [segment])
    end
  end

  def provider_host(_input), do: invalid(:provider_identity)

  @spec repository(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def repository(external_identity) when is_binary(external_identity) do
    with {:ok, normalized} <- normalize_text(external_identity, @max_segment_bytes) do
      build("repository", [digest_token("repository", normalized)])
    end
  end

  def repository(_external_identity), do: invalid(:repository_identity)

  @doc """
  Builds a conceptual repository identity from an internal opaque seed.

  Provider URLs, clone paths, and provider payload values are deliberately not
  admitted as conceptual identity material. Provider identity belongs on a
  `RepositoryLocator` and can be reconciled to this resource only with
  explicit evidence.
  """
  @spec conceptual_repository(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def conceptual_repository(seed) when is_binary(seed) do
    with {:ok, normalized} <- normalize_text(seed, @max_segment_bytes),
         false <- locator_material?(normalized) do
      repository("conceptual:" <> normalized)
    else
      _invalid -> invalid(:conceptual_repository_identity)
    end
  end

  def conceptual_repository(_seed), do: invalid(:conceptual_repository_identity)

  @doc """
  Builds a locator identity from provider host and provider-stable external ID.

  The returned locator IRI does not change when a repository owner or display
  name changes at the provider.
  """
  @spec repository_locator(String.t(), String.t()) ::
          {:ok, %{canonical: String.t(), iri: String.t()}} | {:error, Error.t()}
  def repository_locator(provider, external_id)
      when is_binary(provider) and is_binary(external_id) do
    with {:ok, host} <- normalize_host(provider),
         {:ok, normalized_id} <- normalize_text(external_id, @max_segment_bytes),
         {:ok, host_segment} <- encode_segment(host),
         iri <-
           @base <>
             Enum.join(
               ["repository-locator", host_segment, digest_token("external-id", normalized_id)],
               "/"
             ),
         :ok <- validate(iri) do
      {:ok, %{iri: iri, canonical: "#{host}/id/#{normalized_id}"}}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_locator)
    end
  end

  def repository_locator(_provider, _external_id), do: invalid(:repository_locator)

  @spec repository_locator(String.t(), String.t(), String.t()) ::
          {:ok, %{canonical: String.t(), iri: String.t()}} | {:error, Error.t()}
  def repository_locator(provider, owner, name)
      when is_binary(provider) and is_binary(owner) and is_binary(name) do
    with {:ok, host} <- normalize_host(provider),
         {:ok, canonical_owner} <- normalize_text(owner, @max_segment_bytes),
         {:ok, canonical_name} <- normalize_repository_name(name),
         {:ok, host_segment} <- encode_segment(host),
         {:ok, owner_segment} <- encode_segment(canonical_owner),
         {:ok, name_segment} <- encode_segment(canonical_name),
         {:ok, iri} <- build("repository-locator", [host_segment, owner_segment, name_segment]) do
      {:ok, %{iri: iri, canonical: "#{host}/#{canonical_owner}/#{canonical_name}"}}
    end
  end

  def repository_locator(_provider, _owner, _name), do: invalid(:repository_locator)

  @spec management_enrollment(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def management_enrollment(factory_iri, repository_iri, policy_boundary_iri) do
    with :ok <- validate(factory_iri),
         :ok <- validate(repository_iri),
         :ok <- validate(policy_boundary_iri) do
      deterministic(
        :management_enrollment,
        Enum.join([factory_iri, repository_iri, policy_boundary_iri], "\n")
      )
    end
  end

  @spec enrollment_transition(String.t(), non_neg_integer(), atom() | String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def enrollment_transition(enrollment_iri, revision, state)
      when is_integer(revision) and revision >= 0 do
    state = if is_atom(state), do: Atom.to_string(state), else: state

    with :ok <- validate(enrollment_iri),
         {:ok, normalized_state} <- normalize_text(state, 32) do
      deterministic(
        :enrollment_transition,
        Enum.join([enrollment_iri, Integer.to_string(revision), normalized_state], "\n")
      )
    end
  end

  def enrollment_transition(_enrollment_iri, _revision, _state),
    do: invalid(:enrollment_transition_identity)

  @spec observation_batch(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def observation_batch(enrollment_iri, source, delivery_identity)
      when source in ["poll", "webhook"] and is_binary(delivery_identity) do
    with :ok <- validate(enrollment_iri),
         true <- Regex.match?(~r/^[a-f0-9]{64}$/, delivery_identity) do
      deterministic(
        :observation_batch,
        Enum.join([enrollment_iri, source, delivery_identity], "\n")
      )
    else
      _invalid -> invalid(:observation_batch_identity)
    end
  end

  def observation_batch(_enrollment_iri, _source, _delivery_identity),
    do: invalid(:observation_batch_identity)

  @spec observation_activity(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def observation_activity(batch_iri) do
    with :ok <- validate(batch_iri), do: deterministic(:observation_activity, batch_iri)
  end

  @spec repository_snapshot(String.t(), atom() | String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def repository_snapshot(repository_iri, algorithm, tree_hex) do
    with :ok <- validate(repository_iri),
         {:ok, tree_iri} <- git_object(algorithm, tree_hex) do
      deterministic(:repository_snapshot, repository_iri <> "\n" <> tree_iri)
    end
  end

  @spec provider_object(String.t(), atom() | String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def provider_object(locator_iri, kind, external_id) when is_binary(external_id) do
    kind = if is_atom(kind), do: Atom.to_string(kind), else: kind

    with :ok <- validate(locator_iri),
         {:ok, normalized_kind} <- normalize_text(kind, 64),
         {:ok, normalized_id} <- normalize_text(external_id, @max_segment_bytes) do
      deterministic(
        :provider_object,
        Enum.join([locator_iri, normalized_kind, normalized_id], "\n")
      )
    end
  end

  def provider_object(_locator_iri, _kind, _external_id),
    do: invalid(:provider_object_identity)

  @spec observed_claim(String.t(), RDF.Triple.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def observed_claim(batch_iri, statement) do
    with :ok <- validate(batch_iri),
         {_, _, _} = triple <- RDF.Triple.new(statement),
         true <- RDF.Triple.valid?(triple) and not RDF.Triple.has_bnode?(triple) do
      material =
        [triple]
        |> RDF.Graph.new()
        |> RDF.NTriples.write_string!(sort: true)

      deterministic(:observed_claim, batch_iri <> "\n" <> material)
    else
      _invalid -> invalid(:observed_claim_identity)
    end
  rescue
    _error -> invalid(:observed_claim_identity)
  end

  @spec source_artifact(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def source_artifact(snapshot_iri, relative_path, content_digest)
      when is_binary(relative_path) and is_binary(content_digest) do
    with :ok <- validate(snapshot_iri),
         {:ok, path} <- normalize_relative_path(relative_path),
         true <- Regex.match?(~r/^[a-f0-9]{64}$/, content_digest) do
      deterministic(:source_artifact, Enum.join([snapshot_iri, path, content_digest], "\n"))
    else
      _invalid -> invalid(:source_artifact_identity)
    end
  end

  def source_artifact(_snapshot_iri, _relative_path, _content_digest),
    do: invalid(:source_artifact_identity)

  @spec code_symbol(String.t(), atom() | String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def code_symbol(snapshot_iri, kind, qualified_name) when is_binary(qualified_name) do
    kind = if is_atom(kind), do: Atom.to_string(kind), else: kind

    with :ok <- validate(snapshot_iri),
         {:ok, normalized_kind} <- normalize_text(kind, 64),
         {:ok, normalized_name} <- normalize_text(qualified_name, @max_segment_bytes) do
      deterministic(
        :code_symbol,
        Enum.join([snapshot_iri, normalized_kind, normalized_name], "\n")
      )
    end
  end

  def code_symbol(_snapshot_iri, _kind, _qualified_name),
    do: invalid(:code_symbol_identity)

  @spec source_analysis(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def source_analysis(snapshot_iri, analyzer_version, configuration_digest)
      when is_binary(analyzer_version) and is_binary(configuration_digest) do
    with :ok <- validate(snapshot_iri),
         {:ok, analyzer} <- normalize_text(analyzer_version, 128),
         true <- Regex.match?(~r/^[a-f0-9]{64}$/, configuration_digest) do
      deterministic(
        :source_analysis,
        Enum.join([snapshot_iri, analyzer, configuration_digest], "\n")
      )
    else
      _invalid -> invalid(:source_analysis_identity)
    end
  end

  def source_analysis(_snapshot_iri, _analyzer_version, _configuration_digest),
    do: invalid(:source_analysis_identity)

  @spec git_object(String.t() | atom(), String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def git_object(algorithm, hex) when is_binary(hex) do
    with {:ok, normalized_algorithm} <- normalize_algorithm(algorithm, ["sha1", "sha256"]),
         {:ok, normalized_hex} <- normalize_hex(hex, @digest_lengths[normalized_algorithm]) do
      build("git-object", [normalized_algorithm, normalized_hex])
    end
  end

  def git_object(_algorithm, _hex), do: invalid(:git_object_identity)

  @spec content_digest(String.t() | atom(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def content_digest(algorithm, hex) when is_binary(hex) do
    with {:ok, normalized_algorithm} <- normalize_algorithm(algorithm, ["sha256", "sha512"]),
         {:ok, normalized_hex} <- normalize_hex(hex, @digest_lengths[normalized_algorithm]) do
      build("content", [normalized_algorithm, normalized_hex])
    end
  end

  def content_digest(_algorithm, _hex), do: invalid(:content_identity)

  @spec scope(String.t() | atom(), String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def scope(kind, value) when is_binary(value) do
    with {:ok, kind_segment} <-
           known_kind(kind, ~w[factory organization cohort repository branch path package symbol]),
         {:ok, normalized} <- normalize_text(value, @max_segment_bytes),
         {:ok, value_segment} <- encode_segment(normalized) do
      build("scope", [kind_segment, value_segment])
    end
  end

  def scope(_kind, _value), do: invalid(:scope_identity)

  @spec local(String.t() | atom(), non_neg_integer(), binary()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def local(kind, timestamp_ms, entropy)
      when is_integer(timestamp_ms) and timestamp_ms >= 0 and timestamp_ms <= @max_timestamp and
             is_binary(entropy) and byte_size(entropy) == 10 do
    with {:ok, kind_segment} <- known_kind(kind, @local_kinds) do
      timestamp = timestamp_ms |> :binary.encode_unsigned() |> left_pad(6)
      token = Base.encode16(timestamp <> entropy, case: :lower)
      build(kind_segment, [token])
    end
  end

  def local(_kind, _timestamp_ms, _entropy), do: invalid(:local_identity)

  @spec generate_local(String.t() | atom(), keyword()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def generate_local(kind, options \\ []) do
    clock = Keyword.get(options, :clock, fn -> System.system_time(:millisecond) end)
    random = Keyword.get(options, :random, &:crypto.strong_rand_bytes/1)

    local(kind, clock.(), random.(10))
  rescue
    _error -> invalid(:local_identity)
  catch
    _kind, _reason -> invalid(:local_identity)
  end

  @spec deterministic(String.t() | atom(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def deterministic(kind, material) when is_binary(material) do
    with {:ok, kind_segment} <- known_kind(kind, @deterministic_kinds) do
      build(kind_segment, [digest_token(kind_segment, material)])
    end
  end

  def deterministic(_kind, _material), do: invalid(:deterministic_identity)

  @spec validate(term()) :: :ok | {:error, Error.t()}
  def validate(%RDF.IRI{value: value}), do: validate(value)

  def validate(value) when is_binary(value) do
    normalized = :unicode.characters_to_nfc_binary(value)

    if value == normalized and String.starts_with?(value, @base) and
         byte_size(value) <= @max_iri_bytes and RDF.IRI.valid?(value) and
         not control_character?(value) and not String.contains?(value, ["/../", "/./"]) do
      :ok
    else
      invalid(:resource_identity)
    end
  rescue
    _error -> invalid(:resource_identity)
  end

  def validate(_value), do: invalid(:resource_identity)

  @spec validate_relationship(term()) :: :ok | {:error, Error.t()}
  def validate_relationship({subject, predicate, object}) do
    with :ok <- validate(subject),
         true <- iri?(predicate),
         :ok <- validate(object) do
      :ok
    else
      _invalid -> invalid(:resource_relationship)
    end
  end

  def validate_relationship(_relationship), do: invalid(:resource_relationship)

  @spec graph_token(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def graph_token(resource_iri) do
    with :ok <- validate(resource_iri) do
      {:ok, digest_token("graph-scope", resource_iri)}
    end
  end

  defp normalize_host(input) do
    with {:ok, normalized} <- normalize_text(input, @max_segment_bytes),
         uri <- parse_host_uri(normalized),
         true <- valid_host_uri?(uri),
         host when is_binary(host) <- uri.host,
         canonical_host <- host |> String.downcase() |> String.trim_trailing("."),
         true <- valid_ascii_host?(canonical_host) do
      {:ok, canonical_host_with_port(canonical_host, uri)}
    else
      _invalid -> invalid(:provider_identity)
    end
  end

  defp parse_host_uri(input) do
    if String.contains?(input, "://"), do: URI.parse(input), else: URI.parse("https://" <> input)
  end

  defp valid_host_uri?(uri) do
    uri.scheme in ["http", "https"] and is_nil(uri.userinfo) and
      uri.path in [nil, "", "/"] and is_nil(uri.query) and is_nil(uri.fragment)
  end

  defp valid_ascii_host?(host) do
    byte_size(host) in 1..253 and
      Regex.match?(
        ~r/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)(?:\.(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?))*$/,
        host
      )
  end

  defp canonical_host_with_port(host, %{port: nil}), do: host
  defp canonical_host_with_port(host, %{scheme: "https", port: 443}), do: host
  defp canonical_host_with_port(host, %{scheme: "http", port: 80}), do: host
  defp canonical_host_with_port(host, %{port: port}) when port in 1..65_535, do: "#{host}:#{port}"
  defp canonical_host_with_port(_host, _uri), do: nil

  defp normalize_repository_name(name) do
    name
    |> String.trim()
    |> String.trim_trailing(".git")
    |> normalize_text(@max_segment_bytes)
  end

  defp normalize_text(value, max_bytes) do
    normalized = value |> String.trim() |> :unicode.characters_to_nfc_binary()

    if normalized != "" and byte_size(normalized) <= max_bytes and
         not control_character?(normalized) and normalized not in [".", ".."] and
         not traversal_segment?(normalized) do
      {:ok, normalized}
    else
      invalid(:identity_segment)
    end
  rescue
    _error -> invalid(:identity_segment)
  end

  defp encode_segment(value) do
    {:ok, URI.encode(value, &URI.char_unreserved?/1)}
  rescue
    _error -> invalid(:identity_segment)
  end

  defp normalize_algorithm(algorithm, allowed) do
    value = if is_atom(algorithm), do: Atom.to_string(algorithm), else: algorithm

    if value in allowed, do: {:ok, value}, else: invalid(:digest_algorithm)
  end

  defp normalize_hex(hex, expected_length) do
    normalized = String.downcase(hex)

    if byte_size(normalized) == expected_length and Regex.match?(~r/^[a-f0-9]+$/, normalized) do
      {:ok, normalized}
    else
      invalid(:digest_value)
    end
  end

  defp known_kind(kind, allowed) do
    value = if is_atom(kind), do: kind |> Atom.to_string() |> String.replace("_", "-"), else: kind

    if value in allowed, do: {:ok, value}, else: invalid(:identity_kind)
  end

  defp build(kind, segments) do
    iri = @base <> Enum.join([kind | segments], "/")

    case validate(iri) do
      :ok -> {:ok, iri}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp digest_token(kind, value) do
    :crypto.hash(:sha256, kind <> "\n" <> value)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end

  defp left_pad(binary, size) do
    :binary.copy(<<0>>, size - byte_size(binary)) <> binary
  end

  defp iri?(%RDF.IRI{} = iri), do: RDF.IRI.valid?(iri)
  defp iri?(value) when is_binary(value), do: RDF.IRI.valid?(value)
  defp iri?(_value), do: false

  defp control_character?(value), do: Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp traversal_segment?(value),
    do: value |> String.split(["/", "\\"]) |> Enum.any?(&(&1 in [".", ".."]))

  defp normalize_relative_path(value) do
    normalized = value |> String.replace("\\", "/") |> String.trim()

    if normalized != "" and byte_size(normalized) <= 512 and
         not String.starts_with?(normalized, "/") and not traversal_segment?(normalized) and
         not control_character?(normalized) do
      {:ok, normalized}
    else
      invalid(:source_path)
    end
  end

  defp locator_material?(value) do
    String.contains?(value, ["://", "/", "\\"]) or
      String.starts_with?(String.downcase(value), ["git@", "file:"])
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
