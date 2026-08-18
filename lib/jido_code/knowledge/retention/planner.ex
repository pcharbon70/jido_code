defmodule JidoCode.Knowledge.Retention.Planner do
  @moduledoc "Reachability-first planner for retention, archival, and legal erasure."

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Retention.Plan
  alias JidoCode.Knowledge.Retention.Policy

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_associated "http://www.w3.org/ns/prov#wasAssociatedWith"
  @max_resources 10_000
  @max_removals 900

  @spec plan(map()) :: {:ok, Plan.t()} | {:error, Error.t()}
  def plan(snapshot) when is_map(snapshot) do
    with :ok <- Policy.verify(),
         {:ok, normalized} <- validate_snapshot(snapshot),
         {:ok, reachable} <-
           reachable(normalized.resources, normalized.roots ++ normalized.legal_holds),
         :ok <- reject_held_erasure(normalized.legal_erase, normalized.legal_holds, reachable),
         {:ok, classified} <- classify(normalized, reachable),
         :ok <- reject_unavailable_archive(classified),
         {:ok, plan} <- build_plan(normalized, classified) do
      {:ok, plan}
    end
  end

  def plan(_snapshot), do: {:error, Error.new(:invalid_input, :retention_plan)}

  defp validate_snapshot(snapshot) do
    required = [
      :resources,
      :roots,
      :legal_holds,
      :legal_erase,
      :dataset_revision,
      :graph_revisions,
      :actor_iri,
      :activity_iri,
      :audit_graph_iri,
      :rationale,
      :validation_report_iri
    ]

    with true <- Enum.all?(required, &Map.has_key?(snapshot, &1)),
         true <- is_list(snapshot.resources) and length(snapshot.resources) <= @max_resources,
         true <- valid_iris?(snapshot.roots),
         true <- valid_iris?(snapshot.legal_holds),
         true <- valid_iris?(snapshot.legal_erase),
         true <- valid_iri?(snapshot.actor_iri) and valid_iri?(snapshot.activity_iri),
         true <- valid_graph?(snapshot.audit_graph_iri),
         {:ok, :security_audit} <- GraphRegistry.identify(snapshot.audit_graph_iri),
         true <- valid_iri?(snapshot.validation_report_iri),
         true <- is_integer(snapshot.dataset_revision) and snapshot.dataset_revision >= 0,
         true <- valid_revisions?(snapshot.graph_revisions),
         true <- valid_rationale?(snapshot.rationale),
         true <- Enum.all?(snapshot.resources, &valid_resource?/1),
         true <- unique_resources?(snapshot.resources) do
      {:ok, snapshot}
    else
      _invalid -> {:error, Error.new(:invalid_input, :retention_snapshot)}
    end
  end

  defp reachable(resources, roots) do
    index = Map.new(resources, &{&1.iri, &1})
    walk(index, MapSet.new(roots), roots, 0)
  end

  defp walk(_index, visited, [], _steps), do: {:ok, visited}

  defp walk(index, visited, [iri | pending], steps) when steps <= @max_resources do
    links = index |> Map.get(iri, %{links: []}) |> Map.get(:links, [])
    unseen = Enum.reject(links, &MapSet.member?(visited, &1))
    walk(index, Enum.reduce(unseen, visited, &MapSet.put(&2, &1)), pending ++ unseen, steps + 1)
  end

  defp walk(_index, _visited, _pending, _steps),
    do: {:error, Error.new(:conflict, :retention_reachability)}

  defp reject_held_erasure(erase, holds, reachable) do
    protected = MapSet.union(MapSet.new(holds), reachable)

    if Enum.any?(erase, &MapSet.member?(protected, &1)),
      do: {:error, Error.new(:conflict, :retention_legal_hold)},
      else: :ok
  end

  defp classify(snapshot, reachable) do
    erase = MapSet.new(snapshot.legal_erase)

    result =
      Enum.reduce_while(snapshot.resources, {:ok, empty_classes()}, fn resource, {:ok, acc} ->
        with {:ok, class} <- Policy.class_for_family(resource.family),
             {:ok, disposition} <- Policy.disposition(class, resource.age_days) do
          action =
            cond do
              MapSet.member?(erase, resource.iri) -> :erase
              MapSet.member?(reachable, resource.iri) -> :retain
              true -> disposition
            end

          {:cont, {:ok, Map.update!(acc, action, &[resource | &1])}}
        else
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end
      end)

    case result do
      {:ok, classes} ->
        {:ok, Map.new(classes, fn {key, values} -> {key, Enum.reverse(values)} end)}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp build_plan(snapshot, classified) do
    removed = classified.remove ++ classified.erase
    removals = removed |> Enum.flat_map(& &1.quads) |> Enum.uniq()

    if length(removals) <= @max_removals do
      affected_graphs = removals |> Enum.map(&quad_graph/1) |> Enum.uniq() |> Enum.sort()
      rebuild_graphs = rebuild_graphs(snapshot.resources, removed)
      checksum = checksum(removals)
      plan_id = "urn:jido-code:retention-plan:" <> String.slice(checksum, 0, 32)

      audit_additions =
        audit_additions(snapshot, plan_id, checksum, affected_graphs, classified, rebuild_graphs)

      target_graphs = Enum.sort(Enum.uniq([snapshot.audit_graph_iri | affected_graphs]))

      with true <- Enum.all?(target_graphs, &Map.has_key?(snapshot.graph_revisions, &1)) do
        {:ok,
         %Plan{
           id: plan_id,
           activity_iri: snapshot.activity_iri,
           actor_iri: snapshot.actor_iri,
           audit_graph_iri: snapshot.audit_graph_iri,
           dataset_revision: snapshot.dataset_revision,
           graph_revisions: Map.take(snapshot.graph_revisions, target_graphs),
           retain: iris(classified.retain),
           archive: iris(classified.archive),
           remove: iris(classified.remove),
           erase: iris(classified.erase),
           rebuild_graphs: rebuild_graphs,
           removals: removals,
           audit_additions: audit_additions,
           affected_graphs: target_graphs,
           checksum: checksum,
           rationale: snapshot.rationale,
           validation_report_iri: snapshot.validation_report_iri
         }}
      else
        false -> {:error, Error.new(:invalid_input, :retention_graph_revisions)}
      end
    else
      {:error, Error.new(:conflict, :retention_capacity)}
    end
  end

  defp rebuild_graphs(resources, removed) do
    removed_iris = MapSet.new(removed, & &1.iri)

    resources
    |> Enum.filter(fn resource ->
      resource.family == :derived and
        (resource.age_days > 0 or Enum.any?(resource.links, &MapSet.member?(removed_iris, &1)))
    end)
    |> Enum.map(& &1.graph_iri)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp audit_additions(snapshot, plan_id, checksum, affected_graphs, classified, rebuild_graphs) do
    activity = snapshot.activity_iri
    graph = snapshot.audit_graph_iri

    base = [
      quad(activity, @rdf_type, iri(@jf <> "RetentionActivity"), graph),
      quad(activity, @prov_associated, iri(snapshot.actor_iri), graph),
      quad(activity, @jf <> "retentionPlan", iri(plan_id), graph),
      quad(activity, @jf <> "checksum", RDF.literal(checksum), graph),
      quad(activity, @jf <> "rationale", RDF.literal(snapshot.rationale), graph),
      quad(activity, @jf <> "validationReport", iri(snapshot.validation_report_iri), graph),
      count_quad(activity, "minimumRestoreRevision", snapshot.dataset_revision + 1, graph),
      count_quad(
        activity,
        "archiveEligibleResourceCount",
        length(classified.archive),
        graph
      ),
      count_quad(activity, "removedResourceCount", length(classified.remove), graph),
      count_quad(activity, "erasedResourceCount", length(classified.erase), graph)
    ]

    affected = Enum.map(affected_graphs, &quad(activity, @jf <> "affectedGraph", iri(&1), graph))

    rebuild =
      Enum.map(rebuild_graphs, &quad(activity, @jf <> "requiresDerivedRebuild", iri(&1), graph))

    exact_resources =
      Enum.map(classified.archive ++ classified.remove ++ classified.erase, fn resource ->
        quad(activity, @jf <> "affectedResource", iri(resource.iri), graph)
      end)

    base ++ affected ++ rebuild ++ exact_resources
  end

  defp valid_resource?(resource) do
    is_map(resource) and valid_iri?(resource[:iri]) and valid_graph?(resource[:graph_iri]) and
      is_atom(resource[:family]) and identified_family?(resource.graph_iri, resource.family) and
      is_integer(resource[:age_days]) and resource.age_days >= 0 and valid_iris?(resource[:links]) and
      is_list(resource[:quads]) and resource.quads != [] and
      Enum.all?(resource.quads, &valid_quad?(&1, resource.graph_iri))
  rescue
    _error -> false
  end

  defp valid_quad?(quad, graph_iri) do
    normalized = RDF.Quad.new(quad)

    RDF.Quad.valid?(normalized) and not RDF.Quad.has_bnode?(normalized) and
      quad_graph(normalized) == graph_iri
  rescue
    _error -> false
  end

  defp valid_revisions?(revisions) when is_map(revisions) do
    Enum.all?(revisions, fn {graph, revision} ->
      is_binary(graph) and RDF.IRI.valid?(graph) and is_integer(revision) and revision >= 0
    end)
  end

  defp valid_revisions?(_revisions), do: false

  defp identified_family?(graph_iri, expected_family) do
    case GraphRegistry.identify(graph_iri) do
      {:ok, family} -> family == expected_family
      {:error, _error} -> false
    end
  end

  defp unique_resources?(resources),
    do: resources |> Enum.map(& &1.iri) |> Enum.uniq() |> length() == length(resources)

  defp valid_iris?(values), do: is_list(values) and Enum.all?(values, &valid_iri?/1)
  defp valid_iri?(value), do: Knowledge.validate_resource_identity(value) == :ok
  defp valid_graph?(value), do: is_binary(value) and RDF.IRI.valid?(value)

  defp valid_rationale?(value) do
    is_binary(value) and byte_size(value) in 1..200 and String.valid?(value) and
      not String.contains?(value, ["\n", "\r", "\0"])
  end

  defp checksum(quads) do
    quads
    |> RDF.Dataset.new()
    |> RDF.NQuads.write_string!(sort: true)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp empty_classes, do: %{retain: [], archive: [], remove: [], erase: []}

  defp reject_unavailable_archive(%{archive: []}), do: :ok

  defp reject_unavailable_archive(_classified) do
    {:error, Error.new(:unavailable, :retention_archive_unavailable)}
  end

  defp iris(resources), do: resources |> Enum.map(& &1.iri) |> Enum.sort()
  defp quad_graph({_, _, _, %RDF.IRI{value: graph}}), do: graph

  defp count_quad(subject, predicate, count, graph),
    do: quad(subject, @jf <> predicate, RDF.XSD.NonNegativeInteger.new(count), graph)

  defp quad(subject, predicate, object, graph), do: RDF.quad(subject, predicate, object, graph)
  defp iri(value), do: RDF.iri(value)
end
