defmodule JidoCode.Knowledge.Ontology.Evolution do
  @moduledoc """
  Classifies ontology changes and gates writes that require migration.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Validation.ShapeCatalog

  @classifications [
    :additive_compatible,
    :validation_only,
    :behaviorally_stricter,
    :transform_required,
    :breaking
  ]

  @spec classifications() :: [atom()]
  def classifications, do: @classifications

  @spec classify(map()) :: {:ok, atom()} | {:error, Error.t()}
  def classify(changes) when is_map(changes) do
    removed = list(changes, :removed_terms)
    meaning = list(changes, :meaning_changes)
    shapes = list(changes, :shape_changes)
    added = list(changes, :added_terms)

    classification =
      cond do
        removed != [] -> :breaking
        meaning != [] and Map.get(changes, :transformer_available?, false) -> :transform_required
        meaning != [] -> :breaking
        Map.get(changes, :transform_required?, false) -> :transform_required
        Map.get(changes, :behaviorally_stricter?, false) -> :behaviorally_stricter
        shapes != [] -> :validation_only
        added != [] -> :additive_compatible
        true -> :additive_compatible
      end

    {:ok, classification}
  end

  def classify(_changes), do: {:error, Error.new(:invalid_input, :classify_ontology_change)}

  @spec plan(String.t(), String.t(), atom(), map()) :: {:ok, map()} | {:error, Error.t()}
  def plan(source_version, target_version, classification, attributes \\ %{})

  def plan(source_version, target_version, classification, attributes)
      when classification in @classifications and is_map(attributes) do
    with :ok <- semantic_version(source_version),
         :ok <- semantic_version(target_version),
         :ok <- validate_version_change(source_version, target_version, classification),
         :ok <- validate_plan_attributes(classification, attributes) do
      {:ok,
       %{
         source_version: source_version,
         target_version: target_version,
         classification: classification,
         migration_required?:
           classification in [:behaviorally_stricter, :transform_required, :breaking],
         transformer_version: Map.get(attributes, :transformer_version),
         rollback_posture: Map.get(attributes, :rollback_posture, :retain_source)
       }}
    end
  end

  def plan(_source, _target, _classification, _attributes),
    do: {:error, Error.new(:invalid_input, :ontology_evolution_plan)}

  @spec ensure_writable(String.t(), String.t(), atom(), atom()) :: :ok | {:error, Error.t()}
  def ensure_writable(graph_version, current_version, classification, migration_state)
      when classification in @classifications do
    cond do
      graph_version == current_version ->
        :ok

      classification in [:additive_compatible, :validation_only] ->
        :ok

      migration_state == :complete ->
        :ok

      migration_state in [:missing, :partial] ->
        {:error, Error.new(:incompatible, :required_graph_migration)}

      true ->
        {:error, Error.new(:incompatible, :required_graph_migration)}
    end
  end

  def ensure_writable(_graph_version, _current_version, _classification, _migration_state),
    do: {:error, Error.new(:invalid_input, :required_graph_migration)}

  @spec startup_status([map()], String.t()) :: :ok | {:error, Error.t()}
  def startup_status(graphs, current_version \\ ShapeCatalog.ontology_version())
      when is_list(graphs) do
    if Enum.all?(graphs, &startup_graph_compatible?(&1, current_version)) do
      :ok
    else
      {:error, Error.new(:incompatible, :required_graph_migration)}
    end
  end

  defp startup_graph_compatible?(graph, current_version) do
    ensure_writable(
      Map.get(graph, :ontology_version),
      current_version,
      Map.get(graph, :classification, :breaking),
      Map.get(graph, :migration_state, :missing)
    ) == :ok
  end

  defp validate_version_change(version, version, :additive_compatible), do: :ok
  defp validate_version_change(version, version, :validation_only), do: :ok

  defp validate_version_change(version, version, _classification),
    do: {:error, Error.new(:invalid_input, :ontology_version_reuse)}

  defp validate_version_change(_source, _target, _classification), do: :ok

  defp validate_plan_attributes(:transform_required, attributes) do
    if valid_transformer?(attributes) and valid_rollback?(attributes),
      do: :ok,
      else: {:error, Error.new(:invalid_input, :ontology_evolution_plan)}
  end

  defp validate_plan_attributes(_classification, attributes) do
    if valid_rollback?(attributes),
      do: :ok,
      else: {:error, Error.new(:invalid_input, :ontology_evolution_plan)}
  end

  defp valid_transformer?(attributes) do
    value = Map.get(attributes, :transformer_version)
    is_binary(value) and Regex.match?(~r/^\d+\.\d+\.\d+$/, value)
  end

  defp valid_rollback?(attributes) do
    Map.get(attributes, :rollback_posture, :retain_source) in [
      :retain_source,
      :revert_selector,
      :manual
    ]
  end

  defp semantic_version(value) when is_binary(value) do
    if Regex.match?(~r/^\d+\.\d+\.\d+$/, value),
      do: :ok,
      else: {:error, Error.new(:invalid_input, :ontology_version)}
  end

  defp semantic_version(_value), do: {:error, Error.new(:invalid_input, :ontology_version)}
  defp list(map, key), do: if(is_list(Map.get(map, key, [])), do: Map.get(map, key, []), else: [])
end
