defmodule JidoCode.Knowledge.Execution.Artifact do
  @moduledoc "Content-addressed execution artifact with fail-closed verification."

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Control.ExecutionLease
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.Attempt
  alias JidoCode.Knowledge.Execution.Graph, as: ExecutionGraph
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :kind,
    :base_snapshot_iri,
    :content_digest,
    :media_type,
    :byte_count,
    :generator_iri,
    :affected_paths,
    :affected_symbols,
    :storage,
    :embedded_content,
    :external_uri,
    :findings
  ]
  defstruct @enforce_keys ++ [:proposed_commit_iri, :proposed_tree_iri]

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"
  @text_media_types ~w[text/x-diff text/plain application/json application/yaml]
  @finding_kinds ~w[patch_conflict partial_output rejected_path cleanup_failure artifact_mismatch]a
  @max_embedded_bytes 32_768

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with kind when kind in [:patch, :generated] <- attributes[:kind],
         :ok <- resource(attributes[:base_snapshot_iri]),
         :ok <- resource(attributes[:generator_iri]),
         media_type when is_binary(media_type) and byte_size(media_type) in 1..128 <-
           attributes[:media_type],
         :ok <- paths(attributes[:affected_paths]),
         :ok <- resources(attributes[:affected_symbols]),
         :ok <- optional_resource(attributes[:proposed_commit_iri]),
         :ok <- optional_resource(attributes[:proposed_tree_iri]),
         :ok <- findings(attributes[:findings]),
         {:ok, content} <- content(attributes, media_type),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             artifact_identity_kind(kind),
             Enum.join(
               [
                 attributes.base_snapshot_iri,
                 content.digest,
                 media_type,
                 Integer.to_string(content.byte_count),
                 attributes.generator_iri,
                 Enum.join(Enum.sort(attributes.affected_paths), "\n"),
                 Enum.join(Enum.sort(attributes.affected_symbols), "\n")
               ],
               "\n"
             )
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         kind: kind,
         base_snapshot_iri: attributes.base_snapshot_iri,
         content_digest: content.digest,
         media_type: media_type,
         byte_count: content.byte_count,
         generator_iri: attributes.generator_iri,
         affected_paths: Enum.sort(attributes.affected_paths),
         affected_symbols: Enum.sort(attributes.affected_symbols),
         proposed_commit_iri: attributes[:proposed_commit_iri],
         proposed_tree_iri: attributes[:proposed_tree_iri],
         storage: content.storage,
         embedded_content: content.embedded,
         external_uri: content.external_uri,
         findings: attributes.findings
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_artifact)
    end
  rescue
    _error -> invalid(:execution_artifact)
  end

  def new(_attributes), do: invalid(:execution_artifact)

  @spec record_command(t(), Attempt.t(), map(), ExecutionLease.t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def record_command(artifact, attempt, attempt_resolution, lease, attributes, options \\ [])

  def record_command(
        %__MODULE__{} = artifact,
        %Attempt{} = attempt,
        %{domain: :execution_attempt} = attempt_resolution,
        %ExecutionLease{} = lease,
        attributes,
        options
      )
      when is_map(attributes) and is_list(options) do
    with :ok <- validate_authority(artifact, attempt, attempt_resolution, lease, attributes),
         {:ok, target} <-
           ExecutionGraph.append_target(
             attempt.run_graph_iri,
             attributes.expected_run_revision,
             attributes.repository_scope_iri,
             command_iri(artifact),
             attributes.recorded_at,
             statements(artifact, attempt, attributes.recorded_at)
           ),
         guards = [
           {:subject_absent, attempt.run_graph_iri, artifact.iri},
           {:transition_endpoint, attempt.run_graph_iri, attempt.iri,
            attempt_resolution.current_transition},
           ExecutionLease.execution_guard(
             lease,
             attributes.control_graph_iri,
             attempt.fencing_token,
             attributes.recorded_at
           )
         ],
         {:ok, command} <-
           CommandEnvelope.new(envelope(artifact, attempt, attributes, target, guards), options) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_execution_artifact)
    end
  rescue
    _error -> invalid(:record_execution_artifact)
  end

  def record_command(_artifact, _attempt, _resolution, _lease, _attributes, _options),
    do: invalid(:record_execution_artifact)

  @spec verify(t(), keyword()) :: :ok | {:error, Error.t()}
  def verify(artifact, options \\ [])

  def verify(%__MODULE__{storage: :embedded} = artifact, _options) do
    verify_content(artifact, artifact.embedded_content)
  end

  def verify(%__MODULE__{storage: :external} = artifact, options) when is_list(options) do
    case Keyword.get(options, :fetch) do
      fetch when is_function(fetch, 1) ->
        case fetch.(artifact.external_uri) do
          {:ok, content} when is_binary(content) -> verify_content(artifact, content)
          _unavailable -> {:error, Error.new(:unavailable, :verify_execution_artifact)}
        end

      _missing ->
        {:error, Error.new(:unavailable, :verify_execution_artifact)}
    end
  rescue
    _error -> {:error, Error.new(:unavailable, :verify_execution_artifact)}
  catch
    _kind, _reason -> {:error, Error.new(:unavailable, :verify_execution_artifact)}
  end

  def verify(_artifact, _options), do: invalid(:verify_execution_artifact)

  defp content(%{content: content} = attributes, media_type) when is_binary(content) do
    normalized = normalize(content, media_type)
    digest = content_digest(normalized)

    with true <- media_type in @text_media_types,
         true <- byte_size(normalized) <= @max_embedded_bytes,
         sensitivity when sensitivity in [:public, :internal] <- attributes[:sensitivity],
         false <- secret?(normalized),
         true <- attributes[:external_uri] in [nil, ""],
         true <- attributes[:content_digest] in [nil, digest],
         true <- attributes[:byte_count] in [nil, byte_size(normalized)] do
      {:ok,
       %{
         digest: digest,
         byte_count: byte_size(normalized),
         storage: :embedded,
         embedded: normalized,
         external_uri: nil
       }}
    else
      _invalid -> invalid(:embedded_execution_artifact)
    end
  end

  defp content(attributes, _media_type) do
    with nil <- attributes[:content],
         digest when is_binary(digest) <- attributes[:content_digest],
         true <- Regex.match?(~r/^sha256:[a-f0-9]{64}$/, digest),
         bytes when is_integer(bytes) and bytes in 0..1_073_741_824 <- attributes[:byte_count],
         uri when is_binary(uri) <- attributes[:external_uri],
         %URI{scheme: "https", host: host} when is_binary(host) <- URI.parse(uri),
         true <- String.contains?(uri, String.replace_prefix(digest, "sha256:", "")),
         true <- byte_size(uri) <= 2_048 do
      {:ok,
       %{digest: digest, byte_count: bytes, storage: :external, embedded: nil, external_uri: uri}}
    else
      _invalid -> invalid(:external_execution_artifact)
    end
  end

  defp verify_content(artifact, content) do
    normalized = normalize(content, artifact.media_type)

    if byte_size(normalized) == artifact.byte_count and
         content_digest(normalized) == artifact.content_digest do
      :ok
    else
      {:error, Error.new(:corrupt, :verify_execution_artifact)}
    end
  end

  defp validate_authority(artifact, attempt, resolution, lease, attributes) do
    cond do
      artifact.base_snapshot_iri != attempt.snapshot_iri -> :error
      resolution.subject_iri != attempt.iri -> :error
      resolution.current_state not in [:running, :waiting_tool] -> :error
      lease.iri != attempt.lease_iri or lease.fencing_token != attempt.fencing_token -> :error
      attributes[:fencing_token] != attempt.fencing_token -> :error
      not match?(%DateTime{}, attributes[:recorded_at]) -> :error
      true -> :ok
    end
  end

  defp statements(artifact, attempt, recorded_at) do
    types =
      [{artifact.iri, @rdf_type, RDF.iri(@jf <> "Artifact")}] ++
        if(artifact.kind == :patch,
          do: [{artifact.iri, @rdf_type, RDF.iri(@jf <> "Patch")}],
          else: []
        )

    types ++
      [
        {artifact.iri, @jf <> "artifactKind",
         RDF.iri(@concept <> Macro.camelize(to_string(artifact.kind)) <> "Artifact")},
        {artifact.iri, @jf <> "sourceSnapshot", RDF.iri(artifact.base_snapshot_iri)},
        {artifact.iri, @prov <> "wasGeneratedBy", RDF.iri(artifact.generator_iri)},
        {artifact.iri, @jf <> "contentDigest", RDF.XSD.String.new(artifact.content_digest)},
        {artifact.iri, @jf <> "mediaType", RDF.XSD.String.new(artifact.media_type)},
        {artifact.iri, @jf <> "byteCount", RDF.XSD.NonNegativeInteger.new(artifact.byte_count)},
        {artifact.iri, @jf <> "storageClass",
         RDF.iri(@concept <> Macro.camelize(to_string(artifact.storage)))},
        {artifact.iri, @jf <> "verificationMethod", RDF.XSD.String.new("sha256-on-every-use")},
        {artifact.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(recorded_at)},
        {attempt.iri, @prov <> "generated", RDF.iri(artifact.iri)}
      ] ++
      storage_statements(artifact) ++
      Enum.map(artifact.affected_paths, fn path ->
        {artifact.iri, @jf <> "affectedPath", RDF.XSD.String.new(path)}
      end) ++
      Enum.map(artifact.affected_symbols, fn symbol ->
        {artifact.iri, @jf <> "affects", RDF.iri(symbol)}
      end) ++
      optional_iri(artifact.iri, @jf <> "proposedCommit", artifact.proposed_commit_iri) ++
      optional_iri(artifact.iri, @jf <> "proposedTree", artifact.proposed_tree_iri) ++
      finding_statements(artifact, attempt, recorded_at)
  end

  defp storage_statements(%__MODULE__{storage: :embedded} = artifact),
    do: [{artifact.iri, @jf <> "content", RDF.XSD.String.new(artifact.embedded_content)}]

  defp storage_statements(%__MODULE__{storage: :external} = artifact),
    do: [{artifact.iri, @jf <> "externalOutput", RDF.iri(artifact.external_uri)}]

  defp finding_statements(artifact, attempt, recorded_at) do
    artifact.findings
    |> Enum.with_index()
    |> Enum.flat_map(fn {finding, index} ->
      {:ok, iri} =
        ResourceIdentity.deterministic(
          :artifact_finding,
          artifact.iri <> "\n" <> Integer.to_string(index) <> "\n" <> Atom.to_string(finding.kind)
        )

      [
        {iri, @rdf_type, RDF.iri(@jf <> "Finding")},
        {iri, @jf <> "about", RDF.iri(artifact.iri)},
        {iri, @jf <> "findingKind", RDF.iri(@concept <> Macro.camelize(to_string(finding.kind)))},
        {iri, @jf <> "summary", RDF.XSD.String.new(finding.summary)},
        {iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(recorded_at)},
        {attempt.iri, @jf <> "result", RDF.iri(iri)}
      ]
    end)
  end

  defp envelope(artifact, attempt, attributes, target, guards) do
    command = command_iri(artifact)

    %{
      command_type: "RecordExecutionArtifact",
      command_version: "1.6.0",
      command_iri: command,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:repository_scope_iri],
      idempotency_key: command,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: %{
        attempt.run_graph_iri => attributes.expected_run_revision,
        attributes.control_graph_iri => attributes.expected_control_revision
      },
      reason: attributes[:reason],
      payload: %{changes: [target], guards: guards, artifact_iri: artifact.iri}
    }
  end

  defp command_iri(artifact) do
    {:ok, iri} =
      ResourceIdentity.deterministic(:command_request, artifact.iri <> "\nrecord-artifact")

    iri
  end

  defp artifact_identity_kind(:patch), do: :patch_artifact
  defp artifact_identity_kind(:generated), do: :generated_artifact

  defp normalize(content, media_type) when media_type in @text_media_types do
    content
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> :unicode.characters_to_nfc_binary()
  end

  defp normalize(content, _media_type), do: content

  defp content_digest(content),
    do: "sha256:" <> (:crypto.hash(:sha256, content) |> Base.encode16(case: :lower))

  defp paths(values) when is_list(values) and length(values) <= 100 do
    if Enum.all?(values, &relative_path?/1), do: :ok, else: :error
  end

  defp paths(_values), do: :error

  defp relative_path?(path) when is_binary(path) do
    path != "" and byte_size(path) <= 512 and not String.starts_with?(path, "/") and
      not Enum.any?(String.split(String.replace(path, "\\", "/"), "/"), &(&1 in ["", ".", ".."]))
  end

  defp relative_path?(_path), do: false

  defp resources(values) when is_list(values) and length(values) <= 100 do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)), do: :ok, else: :error
  end

  defp resources(_values), do: :error
  defp resource(value), do: ResourceIdentity.validate(value)
  defp optional_resource(nil), do: :ok
  defp optional_resource(value), do: resource(value)

  defp findings(values) when is_list(values) and length(values) <= 50 do
    if Enum.all?(values, fn
         %{kind: kind, summary: summary}
         when kind in @finding_kinds and is_binary(summary) ->
           byte_size(summary) in 1..512 and not secret?(summary)

         _invalid ->
           false
       end),
       do: :ok,
       else: :error
  end

  defp findings(_values), do: :error

  defp secret?(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp optional_iri(_subject, _predicate, nil), do: []
  defp optional_iri(subject, predicate, object), do: [{subject, predicate, RDF.iri(object)}]
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
