defmodule JidoCode.Knowledge.RepositoryWiki.SemanticContract do
  @moduledoc """
  Executable closed-shape companion for repository-wiki ontology `1.5.0`.

  SHACL declares resource-local cardinality and datatype rules. This module
  closes invariants that span resources or lifecycle state so command code can
  reject an invalid payload before graph construction.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Vocabulary
  alias JidoCode.Knowledge.ResourceIdentity

  @schemas %{
    enrollment: %{
      required: ~w[
        enrollment_iri repository_iri tenant_iri wiki_iri revision state generation_mode
        preview_mode retention_class recorded_at
      ]a,
      optional: ~w[generation_profile_iri current_edition_iri]a
    },
    generation_profile: %{
      required: ~w[
        profile_iri profile_key revision digest generation_mode compiler_profile compiler_digest
        enabled? approved_at
      ]a,
      optional: ~w[expires_at]a
    },
    edition: %{
      required: ~w[
        edition_iri repository_iri tenant_iri wiki_iri graph_iri source_snapshot_iri source_fence
        compiler_profile compiler_digest input_manifest_digest edition_root purpose state
        completeness freshness retention_class current? page_count segment_count statement_count
        content_bytes created_at
      ]a,
      optional: ~w[predecessor_edition_iri lint_report_iri closure_digest]a
    },
    page: %{
      required: ~w[
        page_iri repository_iri tenant_iri edition_iri kind stable_key title slug content_digest
        source_iris
      ]a,
      optional: []
    },
    usage_record: %{
      required: ~w[
        usage_iri repository_iri tenant_iri attempt_iri generation_mode accounting_state
        input_tokens output_tokens cached_tokens reasoning_tokens cost_microunits currency
        recorded_at
      ]a,
      optional: ~w[edition_iri reservation_iri]a
    }
  }

  @terminal_accounting_states ~w[
    rejected success failed cancelled timed_out usage_pending usage_unknown released consumed
  ]a

  @spec validate(atom(), map()) :: :ok | {:error, Error.t()}
  def validate(kind, attributes) when is_atom(kind) and is_map(attributes) do
    with {:ok, schema} <- fetch_schema(kind),
         :ok <- closed_keys(attributes, schema),
         :ok <- validate_kind(kind, attributes) do
      :ok
    end
  end

  def validate(_kind, _attributes), do: invalid(:wiki_shape)

  @spec validate_dataset([{atom(), map()}]) :: :ok | {:error, Error.t()}
  def validate_dataset(resources) when is_list(resources) and resources != [] do
    with :ok <- validate_resources(resources),
         :ok <- one_scope(resources),
         :ok <- one_current_edition(resources) do
      :ok
    end
  end

  def validate_dataset(_resources), do: invalid(:wiki_dataset_shape)

  @spec write_allowed?(atom(), :append | :finalize | :lint | :close | :invalidate) :: boolean()
  def write_allowed?(:building, operation) when operation in [:append, :finalize, :invalidate],
    do: true

  def write_allowed?(:finalized, operation) when operation in [:lint, :invalidate], do: true
  def write_allowed?(:linted, operation) when operation in [:close, :invalidate], do: true
  def write_allowed?(:stale, :invalidate), do: true
  def write_allowed?(_state, _operation), do: false

  defp fetch_schema(kind) do
    case Map.fetch(@schemas, kind) do
      {:ok, schema} -> {:ok, schema}
      :error -> invalid(:wiki_resource_kind)
    end
  end

  defp closed_keys(attributes, schema) do
    keys = Map.keys(attributes)
    allowed = schema.required ++ schema.optional

    if Enum.all?(schema.required, &Map.has_key?(attributes, &1)) and
         Enum.all?(keys, &(&1 in allowed)) do
      :ok
    else
      invalid(:wiki_closed_shape)
    end
  end

  defp validate_kind(:enrollment, attributes) do
    with :ok <- common_scope(attributes),
         :ok <- iri(attributes.enrollment_iri),
         :ok <- iri(attributes.wiki_iri),
         true <- is_integer(attributes.revision) and attributes.revision >= 0,
         true <- Vocabulary.valid?(:enrollment_state, attributes.state),
         true <- Vocabulary.valid?(:generation_mode, attributes.generation_mode),
         true <- Vocabulary.valid?(:preview_mode, attributes.preview_mode),
         true <- Vocabulary.valid?(:retention_class, attributes.retention_class),
         true <- match?(%DateTime{}, attributes.recorded_at),
         :ok <- optional_iri(attributes[:generation_profile_iri]),
         :ok <- optional_iri(attributes[:current_edition_iri]),
         :ok <- enrollment_profile_consistent(attributes) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_enrollment_shape)
    end
  end

  defp validate_kind(:generation_profile, attributes) do
    with :ok <- iri(attributes.profile_iri),
         true <- Vocabulary.valid?(:generation_profile, attributes.profile_key),
         true <- attributes.generation_mode == :deterministic_only,
         true <- is_integer(attributes.revision) and attributes.revision >= 1,
         true <- digest?(attributes.digest),
         true <- attributes.compiler_profile == "wiki-deterministic-elixir/1.0.0",
         true <- digest?(attributes.compiler_digest),
         true <- is_boolean(attributes.enabled?),
         true <- match?(%DateTime{}, attributes.approved_at),
         true <- is_nil(attributes[:expires_at]) or match?(%DateTime{}, attributes.expires_at) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_generation_profile_shape)
    end
  end

  defp validate_kind(:edition, attributes) do
    with :ok <- common_scope(attributes),
         :ok <- iri(attributes.edition_iri),
         :ok <- iri(attributes.wiki_iri),
         :ok <- iri(attributes.source_snapshot_iri),
         {:ok, :repository_wiki} <- GraphRegistry.identify(attributes.graph_iri),
         true <- digest?(attributes.edition_root),
         true <- digest?(attributes.compiler_digest),
         true <- digest?(attributes.input_manifest_digest),
         true <- bounded_string?(attributes.source_fence, 512),
         true <- bounded_string?(attributes.compiler_profile, 128),
         true <- Vocabulary.valid?(:edition_purpose, attributes.purpose),
         true <- Vocabulary.valid?(:edition_state, attributes.state),
         true <- Vocabulary.valid?(:completeness, attributes.completeness),
         true <- Vocabulary.valid?(:freshness, attributes.freshness),
         true <- Vocabulary.valid?(:retention_class, attributes.retention_class),
         true <- is_boolean(attributes.current?),
         true <- counts?(attributes),
         true <- match?(%DateTime{}, attributes.created_at),
         :ok <- optional_iri(attributes[:predecessor_edition_iri]),
         :ok <- optional_iri(attributes[:lint_report_iri]),
         true <- is_nil(attributes[:closure_digest]) or digest?(attributes.closure_digest),
         true <- immutable_state_consistent?(attributes) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_edition_shape)
    end
  end

  defp validate_kind(:page, attributes) do
    with :ok <- common_scope(attributes),
         :ok <- iri(attributes.page_iri),
         :ok <- iri(attributes.edition_iri),
         true <- Vocabulary.valid?(:page_kind, attributes.kind),
         true <- bounded_string?(attributes.stable_key, 160),
         true <- bounded_string?(attributes.title, 256),
         true <- bounded_string?(attributes.slug, 160),
         true <- digest?(attributes.content_digest),
         true <- is_list(attributes.source_iris) and attributes.source_iris != [],
         true <- Enum.all?(attributes.source_iris, &(iri(&1) == :ok)) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_page_shape)
    end
  end

  defp validate_kind(:usage_record, attributes) do
    with :ok <- common_scope(attributes),
         :ok <- iri(attributes.usage_iri),
         :ok <- iri(attributes.attempt_iri),
         :ok <- optional_iri(attributes[:edition_iri]),
         :ok <- optional_iri(attributes[:reservation_iri]),
         true <- Vocabulary.valid?(:generation_mode, attributes.generation_mode),
         true <- attributes.accounting_state in @terminal_accounting_states,
         true <- usage_numbers?(attributes),
         true <- bounded_string?(attributes.currency, 3),
         true <- match?(%DateTime{}, attributes.recorded_at),
         true <- deterministic_usage_consistent?(attributes) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_usage_shape)
    end
  end

  defp validate_resources(resources) do
    Enum.reduce_while(resources, :ok, fn
      {kind, attributes}, :ok ->
        case validate(kind, attributes) do
          :ok -> {:cont, :ok}
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end

      _invalid, :ok ->
        {:halt, invalid(:wiki_dataset_shape)}
    end)
  end

  defp one_scope(resources) do
    scopes =
      resources
      |> Enum.map(fn {_kind, attributes} ->
        {attributes[:repository_iri], attributes[:tenant_iri]}
      end)
      |> Enum.reject(&(&1 == {nil, nil}))
      |> Enum.uniq()

    if length(scopes) <= 1, do: :ok, else: invalid(:wiki_cross_repository)
  end

  defp one_current_edition(resources) do
    current_count =
      Enum.count(resources, fn
        {:edition, %{current?: true}} -> true
        _resource -> false
      end)

    if current_count <= 1, do: :ok, else: invalid(:wiki_multiple_current_editions)
  end

  defp common_scope(attributes) do
    with :ok <- iri(attributes.repository_iri),
         :ok <- iri(attributes.tenant_iri) do
      :ok
    end
  end

  defp enrollment_profile_consistent(attributes) do
    case {attributes.state, attributes[:generation_profile_iri]} do
      {:off, nil} -> :ok
      {:off, _profile} -> invalid(:wiki_off_profile)
      {state, nil} when state in [:manual, :automatic] -> invalid(:wiki_missing_profile)
      {_state, _profile} -> :ok
    end
  end

  defp immutable_state_consistent?(attributes) do
    case attributes.state do
      state when state in [:closed, :superseded] ->
        is_binary(attributes[:closure_digest]) and not is_nil(attributes[:lint_report_iri])

      :building ->
        is_nil(attributes[:closure_digest]) and is_nil(attributes[:lint_report_iri])

      _state ->
        true
    end
  end

  defp counts?(attributes) do
    Enum.all?(~w[page_count segment_count statement_count content_bytes]a, fn key ->
      value = Map.fetch!(attributes, key)
      is_integer(value) and value >= 0
    end)
  end

  defp usage_numbers?(attributes) do
    Enum.all?(~w[input_tokens output_tokens cached_tokens reasoning_tokens cost_microunits]a, fn
      key ->
        value = Map.fetch!(attributes, key)
        is_integer(value) and value >= 0
    end)
  end

  defp deterministic_usage_consistent?(%{generation_mode: :deterministic_only} = attributes) do
    Enum.all?(~w[input_tokens output_tokens cached_tokens reasoning_tokens cost_microunits]a, fn
      key -> Map.fetch!(attributes, key) == 0
    end)
  end

  defp deterministic_usage_consistent?(_attributes), do: true

  defp optional_iri(nil), do: :ok
  defp optional_iri(value), do: iri(value)

  defp iri(value), do: ResourceIdentity.validate(value)

  defp digest?(value) when is_binary(value), do: Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp digest?(_value), do: false

  defp bounded_string?(value, maximum) when is_binary(value),
    do: value != "" and byte_size(value) <= maximum

  defp bounded_string?(_value, _maximum), do: false

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
