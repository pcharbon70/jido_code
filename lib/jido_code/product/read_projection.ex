defmodule JidoCode.Product.ReadProjection do
  @moduledoc """
  Browser-safe, disposable read projection for the native product shell.

  The projection is rebuilt from reviewed graph queries after current named-human
  authorization. It contains opaque presentation references and bounded display
  values only; it is never a grant, durable acknowledgement, command result, or
  source of semantic truth.
  """

  @canonical_states [
    :ready,
    :empty,
    :stale,
    :incomplete,
    :contradicted,
    :truncated,
    :unauthorized,
    :unavailable,
    :maintenance,
    :recovery
  ]
  @protected_states [:unauthorized, :unavailable, :maintenance, :recovery]
  @surfaces [
    :factory,
    :fleet,
    :projects,
    :project,
    :project_attempts,
    :project_wiki,
    :project_dependencies,
    :attempt
  ]

  @enforce_keys [
    :surface,
    :state,
    :source_outcome,
    :query_version,
    :dataset_revision,
    :source_revision_count,
    :generated_at,
    :freshness,
    :complete?,
    :truncated?,
    :attention,
    :attention_families,
    :health,
    :fleet,
    :projects,
    :project,
    :attempts,
    :wiki,
    :dependencies,
    :attempt,
    :summaries,
    :capabilities,
    :warnings,
    :pagination,
    :cache
  ]
  defstruct @enforce_keys

  @type state ::
          :ready
          | :empty
          | :stale
          | :incomplete
          | :contradicted
          | :truncated
          | :unauthorized
          | :unavailable
          | :maintenance
          | :recovery

  @type t :: %__MODULE__{}

  @spec canonical_states() :: [state()]
  def canonical_states, do: @canonical_states

  @spec protected_state?(state()) :: boolean()
  def protected_state?(state), do: state in @protected_states

  @spec new(map()) :: {:ok, t()} | {:error, :invalid_read_projection}
  def new(attributes) when is_map(attributes) do
    with surface when surface in @surfaces <- attributes[:surface],
         state when state in @canonical_states <- attributes[:state],
         source_outcome when is_atom(source_outcome) <- attributes[:source_outcome],
         query_version when is_binary(query_version) <- attributes[:query_version],
         %DateTime{} <- attributes[:generated_at],
         freshness when freshness in [:current, :stale, :unknown] <- attributes[:freshness],
         complete? when is_boolean(complete?) <- attributes[:complete?],
         truncated? when is_boolean(truncated?) <- attributes[:truncated?],
         :ok <- optional_revision(attributes[:dataset_revision]),
         source_revision_count
         when is_integer(source_revision_count) and source_revision_count >= 0 <-
           attributes[:source_revision_count],
         :ok <- bounded_lists(attributes),
         :ok <- optional_map(attributes[:project]),
         :ok <- optional_map(attributes[:wiki]),
         :ok <- optional_map(attributes[:attempt]),
         true <- is_map(attributes[:summaries]),
         true <- is_map(attributes[:pagination]),
         true <- is_map(attributes[:cache]) do
      projection = struct!(__MODULE__, Map.take(attributes, @enforce_keys))
      {:ok, clear_protected(projection)}
    else
      _invalid -> {:error, :invalid_read_projection}
    end
  end

  def new(_attributes), do: {:error, :invalid_read_projection}

  @spec new!(map()) :: t()
  def new!(attributes) do
    case new(attributes) do
      {:ok, projection} -> projection
      {:error, :invalid_read_projection} -> raise ArgumentError, "invalid read projection"
    end
  end

  @spec unavailable(atom(), atom()) :: t()
  def unavailable(surface, source_outcome \\ :unavailable) when surface in @surfaces do
    state = normalize_source_outcome(source_outcome)

    new!(%{
      surface: surface,
      state: state,
      source_outcome: source_outcome,
      query_version: "2.11.0",
      dataset_revision: nil,
      source_revision_count: 0,
      generated_at: DateTime.utc_now() |> DateTime.truncate(:second),
      freshness: :unknown,
      complete?: false,
      truncated?: false,
      attention: [],
      attention_families: [],
      health: [],
      fleet: [],
      projects: [],
      project: nil,
      attempts: [],
      wiki: nil,
      dependencies: [],
      attempt: nil,
      summaries: %{},
      capabilities: [],
      warnings: [safe_warning(source_outcome)],
      pagination: empty_pagination(),
      cache: %{status: :bypass}
    })
  end

  @spec normalize_source_outcome(atom()) :: state()
  def normalize_source_outcome(outcome)
      when outcome in [
             :ready,
             :empty,
             :stale,
             :incomplete,
             :contradicted,
             :truncated,
             :unauthorized,
             :unavailable,
             :maintenance,
             :recovery
           ],
      do: outcome

  def normalize_source_outcome(:partial), do: :incomplete
  def normalize_source_outcome(:contradiction), do: :contradicted
  def normalize_source_outcome(outcome) when outcome in [:concealed, :denied], do: :unauthorized

  def normalize_source_outcome(outcome) when outcome in [:loading, :unconfigured, :error],
    do: :unavailable

  def normalize_source_outcome(_outcome), do: :unavailable

  @spec empty_pagination() :: map()
  def empty_pagination do
    %{
      page: 1,
      page_size: 20,
      known_total: nil,
      page_count: nil,
      previous_href: nil,
      next_href: nil,
      summary: "No authorized rows"
    }
  end

  defp clear_protected(%__MODULE__{state: state} = projection) when state in @protected_states do
    %{
      projection
      | attention: [],
        attention_families: [],
        health: [],
        fleet: [],
        projects: [],
        project: nil,
        attempts: [],
        wiki: nil,
        dependencies: [],
        attempt: nil,
        summaries: %{},
        capabilities: [],
        pagination: empty_pagination()
    }
  end

  defp clear_protected(projection), do: projection

  defp optional_revision(nil), do: :ok
  defp optional_revision(value) when is_integer(value) and value >= 0, do: :ok
  defp optional_revision(_value), do: {:error, :invalid_read_projection}

  defp optional_map(nil), do: :ok
  defp optional_map(value) when is_map(value) and not is_struct(value), do: :ok
  defp optional_map(_value), do: {:error, :invalid_read_projection}

  defp bounded_lists(attributes) do
    keys = [
      :attention,
      :attention_families,
      :health,
      :fleet,
      :projects,
      :attempts,
      :dependencies,
      :capabilities,
      :warnings
    ]

    if Enum.all?(keys, fn key ->
         value = attributes[key]
         is_list(value) and length(value) <= 200
       end),
       do: :ok,
       else: {:error, :invalid_read_projection}
  end

  defp safe_warning(value) when is_atom(value), do: value
  defp safe_warning(_value), do: :unavailable
end
