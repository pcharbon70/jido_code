defmodule JidoCode.Knowledge.RepositoryWiki.Preview do
  @moduledoc """
  Opaque, session-bound candidate-preview identity and authorization contract.

  Preview identity includes every parallel-session fence, while RDF facts keep
  only the closed `WikiPreview` shape. Actor, session, candidate, and reviewer
  bindings stay behind the reviewed preview resolver and never enter ordinary
  repository navigation or search.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Enrollment
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :reference,
    :repository_iri,
    :tenant_iri,
    :edition_iri,
    :source_snapshot_iri,
    :source_fence,
    :compiler_profile,
    :session_iri,
    :attempt_iri,
    :candidate_iri,
    :candidate_digest,
    :fencing_token,
    :actor_iri,
    :reviewer_iris,
    :enrollment_revision,
    :created_at,
    :expires_at,
    :state
  ]
  defstruct @enforce_keys

  @type state :: :active | :expired | :invalidated | :rejected | :retained
  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @maximum_lifetime_seconds 7 * 24 * 60 * 60
  @maximum_reviewers 20
  @reference_prefix "rwp1."

  @spec new(map(), Enrollment.t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def new(edition, %Enrollment{} = enrollment, attributes)
      when is_map(edition) and is_map(attributes) do
    created_at = attributes[:created_at]
    expires_at = attributes[:expires_at]
    reviewers = attributes |> Map.get(:reviewer_iris, []) |> Enum.uniq() |> Enum.sort()

    with true <- edition.purpose == :candidate_preview,
         true <- enrollment.preview_mode == :allowed,
         true <- enrollment.state in [:manual, :automatic],
         true <- enrollment.repository_iri == edition.repository_iri,
         true <- enrollment.tenant_iri == edition.tenant_iri,
         true <- enrollment.revision == attributes[:enrollment_revision],
         :ok <- resources(attributes, edition),
         true <- Contract.digest?(attributes[:candidate_digest]),
         fencing_token when is_integer(fencing_token) and fencing_token > 0 <-
           attributes[:fencing_token],
         true <- valid_interval?(created_at, expires_at),
         true <- length(reviewers) <= @maximum_reviewers,
         true <- Enum.all?(reviewers, &(ResourceIdentity.validate(&1) == :ok)),
         material <- identity_material(edition, attributes, reviewers, created_at, expires_at),
         {:ok, iri} <- ResourceIdentity.deterministic(:wiki_preview, material),
         reference <- opaque_reference(iri, material) do
      {:ok,
       %__MODULE__{
         iri: iri,
         reference: reference,
         repository_iri: edition.repository_iri,
         tenant_iri: edition.tenant_iri,
         edition_iri: edition.iri,
         source_snapshot_iri: edition.source_snapshot_iri,
         source_fence: edition.source_fence,
         compiler_profile: edition.compiler_profile,
         session_iri: attributes.session_iri,
         attempt_iri: attributes.attempt_iri,
         candidate_iri: attributes.candidate_iri,
         candidate_digest: attributes.candidate_digest,
         fencing_token: fencing_token,
         actor_iri: attributes.actor_iri,
         reviewer_iris: reviewers,
         enrollment_revision: enrollment.revision,
         created_at: created_at,
         expires_at: expires_at,
         state: :active
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_preview)
    end
  rescue
    _error -> invalid(:repository_wiki_preview)
  end

  def new(_edition, _enrollment, _attributes), do: invalid(:repository_wiki_preview)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = preview) do
    [
      {preview.iri, @rdf_type, RDF.iri(@jf <> "WikiPreview")},
      {preview.iri, @jf <> "repositoryScope", RDF.iri(preview.repository_iri)},
      {preview.iri, @jf <> "tenantScope", RDF.iri(preview.tenant_iri)},
      {preview.iri, @jf <> "wikiEdition", RDF.iri(preview.edition_iri)},
      {preview.iri, @jf <> "sourceSnapshot", RDF.iri(preview.source_snapshot_iri)},
      {preview.iri, @jf <> "sourceFence", RDF.XSD.String.new(preview.source_fence)},
      {preview.iri, @jf <> "wikiCompilationAttempt", RDF.iri(preview.attempt_iri)},
      {preview.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(preview.created_at)},
      {preview.iri, @jf <> "expiresAt", RDF.XSD.DateTime.new(preview.expires_at)}
    ]
  end

  @spec authorize(t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def authorize(%__MODULE__{} = preview, context) when is_map(context) do
    now = context[:now]

    with true <- preview.state in [:active, :retained],
         %DateTime{} <- now,
         true <- DateTime.compare(now, preview.expires_at) == :lt,
         true <- exact_reference?(preview.reference, context[:preview_reference]),
         true <- context[:repository_iri] == preview.repository_iri,
         true <- context[:tenant_iri] == preview.tenant_iri,
         true <- context[:edition_iri] == preview.edition_iri,
         true <- participant?(preview, context) or reviewer?(preview, context) do
      {:ok,
       %{
         preview_iri: preview.iri,
         edition_iri: preview.edition_iri,
         scope_iri: preview.repository_iri,
         cache_namespace: cache_namespace(preview),
         expires_at: preview.expires_at,
         visibility: :candidate_preview
       }}
    else
      _invalid -> {:error, Error.new(:unauthorized, :repository_wiki_preview_read)}
    end
  end

  def authorize(_preview, _context),
    do: {:error, Error.new(:unauthorized, :repository_wiki_preview_read)}

  @spec transition(t(), atom(), DateTime.t()) :: {:ok, t()} | {:error, Error.t()}
  def transition(%__MODULE__{} = preview, event, %DateTime{} = at) do
    next_state =
      case event do
        :time_limit -> :expired
        :session_closed -> :expired
        :source_drift -> :invalidated
        :enrollment_disabled -> :invalidated
        :rejected -> :rejected
        :candidate_accepted -> :retained
        _unknown -> nil
      end

    cond do
      is_nil(next_state) ->
        invalid(:repository_wiki_preview_transition)

      DateTime.compare(at, preview.created_at) == :lt ->
        invalid(:repository_wiki_preview_transition)

      preview.state not in [:active, :retained] ->
        {:ok, preview}

      true ->
        {:ok, %{preview | state: next_state}}
    end
  end

  def transition(_preview, _event, _at), do: invalid(:repository_wiki_preview_transition)

  @spec cache_namespace(t()) :: String.t()
  def cache_namespace(%__MODULE__{} = preview) do
    Contract.digest(
      Enum.join(
        [preview.reference, preview.edition_iri, Integer.to_string(preview.fencing_token)],
        "\n"
      )
    )
  end

  @spec context_eligible?(t()) :: false
  def context_eligible?(%__MODULE__{}), do: false

  @spec activation_candidate?(t()) :: false
  def activation_candidate?(%__MODULE__{}), do: false

  defp participant?(preview, context) do
    context[:actor_iri] == preview.actor_iri and
      context[:session_iri] == preview.session_iri and
      context[:attempt_iri] == preview.attempt_iri and
      context[:candidate_iri] == preview.candidate_iri and
      context[:source_fence] == preview.source_fence and
      context[:fencing_token] == preview.fencing_token
  end

  defp reviewer?(preview, context) do
    context[:reviewer?] == true and context[:actor_iri] in preview.reviewer_iris and
      optional_exact?(context[:session_iri], preview.session_iri)
  end

  defp optional_exact?(nil, _expected), do: true
  defp optional_exact?(value, expected), do: value == expected

  defp exact_reference?(left, right) when is_binary(left) and is_binary(right) do
    byte_size(left) == byte_size(right) and Plug.Crypto.secure_compare(left, right)
  end

  defp exact_reference?(_left, _right), do: false

  defp valid_interval?(%DateTime{} = created_at, %DateTime{} = expires_at) do
    Contract.valid_interval?(created_at, expires_at) and
      DateTime.diff(expires_at, created_at, :second) <= @maximum_lifetime_seconds
  end

  defp valid_interval?(_created_at, _expires_at), do: false

  defp resources(attributes, edition) do
    values = [
      attributes[:session_iri],
      attributes[:attempt_iri],
      attributes[:candidate_iri],
      attributes[:actor_iri],
      edition.iri,
      edition.repository_iri,
      edition.tenant_iri,
      edition.source_snapshot_iri
    ]

    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: :ok,
      else: invalid(:repository_wiki_preview_identity)
  end

  defp identity_material(edition, attributes, reviewers, created_at, expires_at) do
    Contract.digest(%{
      repository_iri: edition.repository_iri,
      tenant_iri: edition.tenant_iri,
      edition_iri: edition.iri,
      source_snapshot_iri: edition.source_snapshot_iri,
      source_fence: edition.source_fence,
      compiler_profile: edition.compiler_profile,
      session_iri: attributes.session_iri,
      attempt_iri: attributes.attempt_iri,
      candidate_iri: attributes.candidate_iri,
      candidate_digest: attributes.candidate_digest,
      fencing_token: attributes.fencing_token,
      actor_iri: attributes.actor_iri,
      reviewer_iris: reviewers,
      enrollment_revision: attributes.enrollment_revision,
      created_at: created_at,
      expires_at: expires_at
    })
  end

  defp opaque_reference(iri, material) do
    digest = :crypto.hash(:sha256, iri <> "\n" <> material)
    @reference_prefix <> Base.url_encode64(digest, padding: false)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
