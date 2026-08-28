defmodule JidoCode.Knowledge.RepositoryWiki.ContextSource do
  @moduledoc """
  Builds bounded current-edition wiki context from an authorized reviewed read.

  The reader is a replaceable projection port, but its result must repeat every
  material authorization and source fence. Preview, stale, hidden, invalid,
  superseded, cross-scope, and oversized observations fail closed or become
  deterministic omissions without exposing their content.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.ContextPacket
  alias JidoCode.Knowledge.RepositoryWiki.ContextProfile
  alias JidoCode.Knowledge.RepositoryWiki.Contract

  @required_request ~w[
    actor_iri tenant_iri repository_iri task_iri session_iri attempt_iri source_snapshot_iri
    source_revision enrollment_revision edition_iri edition_root compiler_profile compiler_digest
    dataset_revision wiki_graph_iri wiki_graph_revision evaluated_at enrollment_visible?
    task_authorized?
  ]a
  @required_edition ~w[
    tenant_iri repository_iri source_snapshot_iri source_revision enrollment_revision edition_iri
    edition_root compiler_profile compiler_digest dataset_revision wiki_graph_iri
    wiki_graph_revision state purpose freshness current? preview? visible?
  ]a
  @required_fragment ~w[
    fragment_iri page_iri page_kind content content_digest source_iris source_digests
    authority_class confidence_basis_points freshness classification dependency_iris guide_iris
    gap_iris contradictory? current? preview? visible? superseded? invalid? tenant_iri
    repository_iri source_snapshot_iri source_revision enrollment_revision edition_iri
    edition_root compiler_profile compiler_digest
  ]a
  @authority_classes [:authored, :deterministic, :gap]
  @classifications [:public, :internal, :confidential]

  @spec profile() :: ContextProfile.t()
  def profile, do: ContextProfile.profile()

  @spec load(map(), keyword()) :: {:ok, ContextPacket.t()} | {:error, Error.t()}
  def load(request, options \\ [])

  def load(request, options) when is_map(request) and is_list(options) do
    profile = ContextProfile.profile()
    reader = Keyword.get(options, :reader)

    with :ok <- validate_request(request, profile),
         true <- is_function(reader, 2),
         {:ok, projection} <- reader.(request, profile),
         :ok <- validate_projection_scope(projection, request),
         {:ok, fragments, omissions, usage} <-
           select_fragments(projection.fragments, request, profile) do
      {:ok,
       ContextPacket.build(%{
         profile_key: profile.key,
         profile_digest: profile.digest,
         actor_iri: request.actor_iri,
         tenant_iri: request.tenant_iri,
         repository_iri: request.repository_iri,
         task_iri: request.task_iri,
         session_iri: request.session_iri,
         attempt_iri: request.attempt_iri,
         source_snapshot_iri: request.source_snapshot_iri,
         source_revision: request.source_revision,
         enrollment_revision: request.enrollment_revision,
         edition_iri: request.edition_iri,
         edition_root: request.edition_root,
         compiler_profile: request.compiler_profile,
         compiler_digest: request.compiler_digest,
         dataset_revision: request.dataset_revision,
         wiki_graph_iri: request.wiki_graph_iri,
         wiki_graph_revision: request.wiki_graph_revision,
         fragments: fragments,
         omissions: omissions,
         usage: usage,
         evaluated_at: DateTime.truncate(request.evaluated_at, :microsecond)
       })}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_context_source)
    end
  rescue
    _error -> invalid(:repository_wiki_context_source)
  end

  def load(_request, _options), do: invalid(:repository_wiki_context_source)

  @spec current?(ContextPacket.t(), map()) :: boolean()
  def current?(%ContextPacket{} = packet, current) when is_map(current) do
    ContextPacket.valid?(packet) and
      Enum.all?(
        [
          {:actor_iri, packet.actor_iri},
          {:tenant_iri, packet.tenant_iri},
          {:repository_iri, packet.repository_iri},
          {:task_iri, packet.task_iri},
          {:session_iri, packet.session_iri},
          {:attempt_iri, packet.attempt_iri},
          {:source_snapshot_iri, packet.source_snapshot_iri},
          {:source_revision, packet.source_revision},
          {:enrollment_revision, packet.enrollment_revision},
          {:edition_iri, packet.edition_iri},
          {:edition_root, packet.edition_root},
          {:compiler_profile, packet.compiler_profile},
          {:compiler_digest, packet.compiler_digest},
          {:dataset_revision, packet.dataset_revision},
          {:wiki_graph_revision, packet.wiki_graph_revision},
          {:profile_digest, packet.profile_digest}
        ],
        fn {key, expected} -> current[key] == expected end
      ) and current[:enrollment_visible?] == true and current[:task_authorized?] == true
  end

  def current?(%ContextPacket{}, _current), do: false

  defp validate_request(request, profile) do
    resources =
      ~w[actor_iri tenant_iri repository_iri task_iri session_iri attempt_iri source_snapshot_iri edition_iri]a

    with true <- Enum.all?(@required_request, &Map.has_key?(request, &1)),
         true <- Enum.all?(resources, &(Contract.resource(request[&1]) == :ok)),
         {:ok, :repository_wiki} <- GraphRegistry.identify(request.wiki_graph_iri),
         true <- bounded_text?(request.source_revision, 512),
         true <- bounded_text?(request.compiler_profile, 128),
         true <- Contract.digest?(request.edition_root),
         true <- Contract.digest?(request.compiler_digest),
         true <- nonnegative?(request.enrollment_revision),
         true <- nonnegative?(request.dataset_revision),
         true <- nonnegative?(request.wiki_graph_revision),
         true <- request.enrollment_visible? == true,
         true <- request.task_authorized? == true,
         %DateTime{} <- request.evaluated_at,
         true <- request.evaluated_at == DateTime.truncate(request.evaluated_at, :microsecond),
         true <- ContextProfile.valid?(profile) do
      :ok
    else
      _invalid -> invalid(:repository_wiki_context_request)
    end
  end

  defp validate_projection_scope(%{edition: edition, fragments: fragments}, request)
       when is_map(edition) and is_list(fragments) do
    with true <- Enum.all?(@required_edition, &Map.has_key?(edition, &1)),
         :ok <- exact_edition(edition, request),
         true <- edition.state == :closed,
         true <- edition.purpose in [:current, :release],
         true <- edition.freshness == :current,
         true <- edition.current? == true,
         true <- edition.preview? == false,
         true <- edition.visible? == true do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> stale(:repository_wiki_context_projection)
    end
  end

  defp validate_projection_scope(_projection, _request),
    do: invalid(:repository_wiki_context_projection)

  defp exact_edition(edition, request) do
    fields = ~w[
      tenant_iri repository_iri source_snapshot_iri source_revision enrollment_revision edition_iri
      edition_root compiler_profile compiler_digest dataset_revision wiki_graph_iri
      wiki_graph_revision
    ]a

    if Enum.all?(fields, &(edition[&1] == request[&1])) do
      :ok
    else
      stale(:repository_wiki_context_fence)
    end
  end

  defp select_fragments(fragments, request, profile)
       when is_list(fragments) and length(fragments) <= 200 do
    fragments
    |> Enum.reduce_while({:ok, [], []}, fn fragment, {:ok, accepted, omitted} ->
      case normalize_fragment(fragment, request, profile) do
        {:ok, normalized} ->
          {:cont, {:ok, [normalized | accepted], omitted}}

        {:omit, reason, safe_key} ->
          {:cont, {:ok, accepted, [%{key: safe_key, reason: reason} | omitted]}}

        {:error, %Error{} = error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, accepted, omitted} ->
        accepted = Enum.sort_by(accepted, &rank_key/1)
        {selected, bounded_omissions} = bound_by_class_and_packet(accepted, profile)
        omissions = Enum.reverse(omitted) ++ bounded_omissions

        usage = %{
          fragments: length(selected),
          bytes: Enum.sum(Enum.map(selected, & &1.bytes)),
          estimated_tokens: Enum.sum(Enum.map(selected, & &1.estimated_tokens)),
          omitted: length(omissions)
        }

        {:ok, selected, omissions, usage}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp select_fragments(_fragments, _request, _profile),
    do: invalid(:repository_wiki_context_fragments)

  defp normalize_fragment(fragment, request, profile) when is_map(fragment) do
    with true <- Map.keys(fragment) |> Enum.all?(&(&1 in @required_fragment)),
         true <- Enum.all?(@required_fragment, &Map.has_key?(fragment, &1)),
         :ok <- exact_fragment_scope(fragment, request),
         :ok <- fragment_resources(fragment),
         {:ok, page_class} <- ContextProfile.page_class(fragment.page_kind),
         true <- fragment.authority_class in @authority_classes,
         true <- fragment.classification in @classifications,
         true <- is_integer(fragment.confidence_basis_points),
         true <- fragment.confidence_basis_points in 0..10_000,
         true <- is_boolean(fragment.contradictory?),
         true <- Contract.digest?(fragment.content_digest),
         true <- Enum.all?(fragment.source_digests, &Contract.digest?/1),
         true <- is_binary(fragment.content),
         content <- fragment.content |> String.trim() |> :unicode.characters_to_nfc_binary(),
         true <- content != "",
         safe_key <- Contract.digest({fragment.page_iri, fragment.fragment_iri}) do
      cond do
        fragment.preview? ->
          {:omit, :preview_forbidden, safe_key}

        fragment.superseded? ->
          {:omit, :superseded_edition, safe_key}

        fragment.invalid? ->
          {:omit, :invalid_edition, safe_key}

        not fragment.current? ->
          {:omit, :not_current, safe_key}

        not fragment.visible? ->
          {:omit, :hidden, safe_key}

        fragment.freshness != profile.freshness ->
          {:omit, :stale, safe_key}

        fragment.confidence_basis_points < profile.minimum_confidence_basis_points ->
          {:omit, :confidence, safe_key}

        byte_size(content) > profile.maximum_fragment_bytes ->
          {:omit, :fragment_byte_limit, safe_key}

        token_estimate(content) > profile.maximum_estimated_tokens ->
          {:omit, :fragment_token_limit, safe_key}

        true ->
          provenance = %{
            edition_iri: fragment.edition_iri,
            edition_root: fragment.edition_root,
            page_iri: fragment.page_iri,
            fragment_iri: fragment.fragment_iri,
            source_iris: Enum.sort(fragment.source_iris),
            source_digests: Enum.sort(fragment.source_digests),
            compiler_profile: fragment.compiler_profile,
            compiler_digest: fragment.compiler_digest,
            freshness: fragment.freshness,
            confidence_basis_points: fragment.confidence_basis_points,
            dependency_iris: Enum.sort(fragment.dependency_iris),
            guide_iris: Enum.sort(fragment.guide_iris),
            gap_iris: Enum.sort(fragment.gap_iris),
            authority_class: fragment.authority_class,
            source_revision: fragment.source_revision
          }

          {:ok,
           %{
             iri: fragment.fragment_iri,
             page_iri: fragment.page_iri,
             page_kind: fragment.page_kind,
             page_class: page_class,
             classification: fragment.classification,
             authority_class: fragment.authority_class,
             confidence_basis_points: fragment.confidence_basis_points,
             contradictory?: fragment.contradictory?,
             content: content,
             content_digest: fragment.content_digest,
             source_iris: Enum.sort(fragment.source_iris),
             source_digests: Enum.sort(fragment.source_digests),
             provenance: provenance,
             provenance_digest: Contract.digest(provenance),
             bytes: byte_size(content),
             estimated_tokens: token_estimate(content),
             advisory?: true,
             authority?: false
           }}
      end
    else
      :error -> {:omit, :unsupported_page_class, safe_fragment_key(fragment)}
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_context_fragment)
    end
  rescue
    _error -> invalid(:repository_wiki_context_fragment)
  end

  defp normalize_fragment(_fragment, _request, _profile),
    do: invalid(:repository_wiki_context_fragment)

  defp exact_fragment_scope(fragment, request) do
    fields = ~w[
      tenant_iri repository_iri source_snapshot_iri source_revision enrollment_revision edition_iri
      edition_root compiler_profile compiler_digest
    ]a

    if Enum.all?(fields, &(fragment[&1] == request[&1])) do
      :ok
    else
      {:error, Error.new(:unauthorized, :repository_wiki_context_scope)}
    end
  end

  defp fragment_resources(fragment) do
    collections = ~w[source_iris dependency_iris guide_iris gap_iris]a

    if Contract.resource(fragment.fragment_iri) == :ok and
         Contract.resource(fragment.page_iri) == :ok and
         Enum.all?(collections, fn key ->
           value = fragment[key]

           is_list(value) and length(value) <= 64 and
             Enum.all?(value, &(Contract.resource(&1) == :ok))
         end) and fragment.source_iris != [] and
         length(fragment.source_digests) == length(fragment.source_iris) do
      :ok
    else
      invalid(:repository_wiki_context_fragment_identity)
    end
  end

  defp bound_by_class_and_packet(fragments, profile) do
    initial = {%{}, %{fragments: 0, bytes: 0, tokens: 0}, [], []}

    {_class_usage, _usage, selected, omissions} =
      Enum.reduce(fragments, initial, fn fragment, {classes, usage, selected, omissions} ->
        class_count = Map.get(classes, fragment.page_class, 0)

        reason =
          cond do
            class_count + 1 > ContextProfile.class_limit(profile, fragment.page_class) ->
              :page_class_limit

            usage.fragments + 1 > profile.maximum_fragments ->
              :fragment_limit

            usage.bytes + fragment.bytes > profile.maximum_bytes ->
              :packet_byte_limit

            usage.tokens + fragment.estimated_tokens > profile.maximum_estimated_tokens ->
              :packet_token_limit

            true ->
              nil
          end

        if is_nil(reason) do
          {
            Map.put(classes, fragment.page_class, class_count + 1),
            %{
              fragments: usage.fragments + 1,
              bytes: usage.bytes + fragment.bytes,
              tokens: usage.tokens + fragment.estimated_tokens
            },
            [fragment | selected],
            omissions
          }
        else
          omission = %{key: Contract.digest({fragment.page_iri, fragment.iri}), reason: reason}
          {classes, usage, selected, [omission | omissions]}
        end
      end)

    {Enum.reverse(selected), Enum.reverse(omissions)}
  end

  defp rank_key(fragment) do
    gap_rank = if fragment.page_class == :known_gaps, do: 0, else: 1
    contradiction_rank = if fragment.contradictory?, do: 0, else: 1

    {gap_rank, contradiction_rank, -fragment.confidence_basis_points, fragment.page_class,
     fragment.page_iri, fragment.iri}
  end

  defp safe_fragment_key(fragment) do
    Contract.digest({Map.get(fragment, :page_kind), Map.get(fragment, :page_iri)})
  end

  defp token_estimate(value), do: div(byte_size(value) + 3, 4)
  defp nonnegative?(value), do: is_integer(value) and value >= 0
  defp bounded_text?(value, maximum), do: is_binary(value) and byte_size(value) in 1..maximum
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp stale(operation), do: {:error, Error.new(:stale_precondition, operation)}
end
