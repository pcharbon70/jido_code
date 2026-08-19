defmodule JidoCode.Knowledge.Execution.Graph do
  @moduledoc false

  alias JidoCode.Knowledge.Control.Graph, as: ControlGraph
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @spec run_graph(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def run_graph(attempt_iri), do: GraphRegistry.graph_iri(:run_attempt, %{attempt: attempt_iri})

  @spec segment_graph(String.t(), non_neg_integer()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def segment_graph(attempt_iri, index),
    do: GraphRegistry.graph_iri(:run_event_segment, %{attempt: attempt_iri, segment: index})

  @spec create_target(String.t(), String.t(), String.t(), DateTime.t(), list()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_target(graph_iri, owner_scope, activity, created_at, additions)
      when is_list(additions) do
    create_run_target(
      graph_iri,
      owner_scope,
      activity,
      created_at,
      additions,
      "https://jido.run/ontology/release/1.0.0"
    )
  end

  def create_target(_graph, _scope, _activity, _created_at, _additions),
    do: invalid(:execution_graph_create)

  @spec create_segmented_run_target(String.t(), String.t(), String.t(), DateTime.t(), list()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_segmented_run_target(graph_iri, owner_scope, activity, created_at, additions)
      when is_list(additions) do
    create_run_target(
      graph_iri,
      owner_scope,
      activity,
      created_at,
      additions,
      "https://jido.run/ontology/release/1.2.0"
    )
  end

  def create_segmented_run_target(_graph, _scope, _activity, _created_at, _additions),
    do: invalid(:execution_graph_create)

  defp create_run_target(
         graph_iri,
         owner_scope,
         activity,
         created_at,
         additions,
         ontology_version
       ) do
    with {:ok, :run_attempt} <- GraphRegistry.identify(graph_iri),
         :ok <- ResourceIdentity.validate(owner_scope),
         :ok <- ResourceIdentity.validate(activity),
         true <- match?(%DateTime{}, created_at),
         {:ok, metadata} <-
           GraphMetadata.new(graph_iri, %{
             owner_scope: owner_scope,
             ontology_version: ontology_version,
             creation_activity: activity,
             created_at: created_at,
             lifecycle_state: :open,
             completeness_state: :building,
             graph_revision: 1
           }),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata) do
      {:ok,
       %{
         family: :run_attempt,
         graph_iri: graph_iri,
         operation: :create,
         metadata: metadata,
         additions: metadata_quads ++ additions,
         supersessions: [],
         invalidations: [],
         removals: []
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_graph_create)
    end
  end

  @spec create_segment_target(
          String.t(),
          String.t(),
          String.t(),
          DateTime.t(),
          list(),
          String.t() | nil
        ) :: {:ok, map()} | {:error, Error.t()}
  def create_segment_target(
        graph_iri,
        owner_scope,
        activity,
        created_at,
        additions,
        parent_graph \\ nil
      )

  def create_segment_target(
        graph_iri,
        owner_scope,
        activity,
        created_at,
        additions,
        parent_graph
      )
      when is_list(additions) do
    with {:ok, :run_event_segment} <- GraphRegistry.identify(graph_iri),
         :ok <- ResourceIdentity.validate(owner_scope),
         :ok <- ResourceIdentity.validate(activity),
         true <- match?(%DateTime{}, created_at),
         {:ok, metadata} <-
           GraphMetadata.new(graph_iri, %{
             owner_scope: owner_scope,
             ontology_version: "https://jido.run/ontology/release/1.2.0",
             creation_activity: activity,
             created_at: created_at,
             lifecycle_state: :open,
             completeness_state: :building,
             graph_revision: 1,
             parent_graph: parent_graph
           }),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata) do
      {:ok,
       %{
         family: :run_event_segment,
         graph_iri: graph_iri,
         operation: :create,
         metadata: metadata,
         additions: metadata_quads ++ additions,
         supersessions: [],
         invalidations: [],
         removals: []
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:event_segment_graph_create)
    end
  end

  def create_segment_target(_graph, _scope, _activity, _created_at, _additions, _parent),
    do: invalid(:event_segment_graph_create)

  @spec append_target(String.t(), non_neg_integer(), String.t(), String.t(), DateTime.t(), list()) ::
          {:ok, map()} | {:error, Error.t()}
  def append_target(graph_iri, revision, owner_scope, activity, recorded_at, additions)
      when is_integer(revision) and revision >= 0 and is_list(additions) do
    with {:ok, family} <- GraphRegistry.identify(graph_iri),
         :ok <- ResourceIdentity.validate(owner_scope),
         :ok <- ResourceIdentity.validate(activity),
         true <- match?(%DateTime{}, recorded_at) do
      case family do
        :repository_control ->
          ControlGraph.target(graph_iri, revision, owner_scope, activity, recorded_at, additions)

        :run_attempt when revision > 0 ->
          {:ok,
           %{
             family: :run_attempt,
             graph_iri: graph_iri,
             operation: :append,
             metadata: %{lifecycle_state: :open},
             additions: additions,
             supersessions: [],
             invalidations: [],
             removals: []
           }}

        :run_event_segment when revision > 0 ->
          {:ok,
           %{
             family: :run_event_segment,
             graph_iri: graph_iri,
             operation: :append,
             metadata: %{lifecycle_state: :open},
             additions: additions,
             supersessions: [],
             invalidations: [],
             removals: []
           }}

        _unsupported ->
          invalid(:execution_graph_target)
      end
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_graph_target)
    end
  end

  def append_target(_graph, _revision, _scope, _activity, _recorded_at, _additions),
    do: invalid(:execution_graph_target)

  @spec close_target(map(), String.t(), String.t(), DateTime.t(), :complete | :incomplete, list()) ::
          {:ok, map()} | {:error, Error.t()}
  def close_target(metadata, owner_scope, activity, closed_at, completeness, additions)
      when is_map(metadata) and completeness in [:complete, :incomplete] and is_list(additions) do
    graph_iri = metadata[:graph_iri]

    with {:ok, :run_attempt} <- GraphRegistry.identify(graph_iri),
         true <- metadata[:family] == :run_attempt,
         true <- metadata[:lifecycle_state] == :open,
         true <- metadata[:completeness_state] == :building,
         :ok <- ResourceIdentity.validate(owner_scope),
         :ok <- ResourceIdentity.validate(activity),
         true <- match?(%DateTime{}, closed_at),
         true <- owner_scope == metadata[:owner_scope],
         {:ok, closed_metadata} <-
           GraphMetadata.new(graph_iri, %{
             owner_scope: metadata.owner_scope,
             ontology_version: metadata.ontology_version,
             creation_activity: metadata.creation_activity,
             created_at: metadata.created_at,
             lifecycle_state: :closed,
             completeness_state: completeness,
             closed_at: closed_at,
             graph_revision: metadata.graph_revision
           }) do
      {:ok,
       %{
         family: :run_attempt,
         graph_iri: graph_iri,
         operation: :close,
         metadata: closed_metadata,
         additions:
           [
             {graph_iri, @jf <> "lifecycleState", RDF.iri(@concept <> "Closed")},
             {graph_iri, @jf <> "completenessState",
              RDF.iri(@concept <> Macro.camelize(to_string(completeness)))},
             {graph_iri, @jf <> "closedAt", RDF.XSD.DateTime.new(closed_at)}
           ] ++ additions,
         supersessions: [],
         invalidations: [],
         removals: [
           {graph_iri, @jf <> "lifecycleState", RDF.iri(@concept <> "Open")},
           {graph_iri, @jf <> "completenessState", RDF.iri(@concept <> "Building")}
         ]
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_graph_close)
    end
  rescue
    _error -> invalid(:execution_graph_close)
  end

  def close_target(_metadata, _scope, _activity, _closed_at, _completeness, _additions),
    do: invalid(:execution_graph_close)

  @spec close_segment_target(
          map(),
          String.t(),
          String.t(),
          DateTime.t(),
          :complete | :incomplete,
          list()
        ) :: {:ok, map()} | {:error, Error.t()}
  def close_segment_target(metadata, owner_scope, activity, closed_at, completeness, additions)
      when is_map(metadata) and completeness in [:complete, :incomplete] and is_list(additions) do
    graph_iri = metadata[:graph_iri]

    with {:ok, :run_event_segment} <- GraphRegistry.identify(graph_iri),
         true <- metadata[:family] == :run_event_segment,
         true <- metadata[:lifecycle_state] == :open,
         true <- metadata[:completeness_state] == :building,
         true <- metadata[:owner_scope] == owner_scope,
         :ok <- ResourceIdentity.validate(owner_scope),
         :ok <- ResourceIdentity.validate(activity),
         true <- match?(%DateTime{}, closed_at),
         {:ok, closed_metadata} <-
           GraphMetadata.new(graph_iri, %{
             owner_scope: metadata.owner_scope,
             ontology_version: metadata.ontology_version,
             creation_activity: metadata.creation_activity,
             created_at: metadata.created_at,
             lifecycle_state: :closed,
             completeness_state: completeness,
             closed_at: closed_at,
             graph_revision: metadata.graph_revision,
             parent_graph: metadata[:parent_graph]
           }) do
      {:ok,
       %{
         family: :run_event_segment,
         graph_iri: graph_iri,
         operation: :close,
         metadata: closed_metadata,
         additions:
           [
             {graph_iri, @jf <> "lifecycleState", RDF.iri(@concept <> "Closed")},
             {graph_iri, @jf <> "completenessState",
              RDF.iri(@concept <> Macro.camelize(to_string(completeness)))},
             {graph_iri, @jf <> "closedAt", RDF.XSD.DateTime.new(closed_at)}
           ] ++ additions,
         supersessions: [],
         invalidations: [],
         removals: [
           {graph_iri, @jf <> "lifecycleState", RDF.iri(@concept <> "Open")},
           {graph_iri, @jf <> "completenessState", RDF.iri(@concept <> "Building")}
         ]
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:event_segment_graph_close)
    end
  rescue
    _error -> invalid(:event_segment_graph_close)
  end

  def close_segment_target(_metadata, _scope, _activity, _closed_at, _complete, _additions),
    do: invalid(:event_segment_graph_close)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
