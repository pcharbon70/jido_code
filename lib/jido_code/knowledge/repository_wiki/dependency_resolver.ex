defmodule JidoCode.Knowledge.RepositoryWiki.DependencyResolver do
  @moduledoc "Complete deterministic dependency closure from reconciled declarations and lock evidence."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

  @profile "wiki-dependency-resolver/1.0.0"
  @maximums %{nodes: 2_048, edges: 16_384, depth: 64, paths: 2_048}

  @spec profile() :: map()
  def profile,
    do: %{
      revision: @profile,
      limits: @maximums,
      traversal: :cycle_safe_breadth_first,
      root_path: :lexicographically_canonical_shortest,
      model_calls: 0
    }

  @spec resolve(map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def resolve(reconciliation, attributes)
      when is_map(reconciliation) and is_map(attributes) do
    limits = Map.get(attributes, :limits, @maximums)
    resolver_attributes = Map.put(attributes, :reconciliation_digest, reconciliation[:digest])

    with :ok <- validate(reconciliation, attributes, limits),
         declarations <- declarations(reconciliation),
         locks <- Map.new(reconciliation.lock_entries, &{&1.name, &1}),
         {:ok, edges} <- edges(reconciliation.lock_entries, limits),
         names <- names(declarations, locks, edges),
         true <- length(names) <= limits.nodes,
         roots <- declarations |> Map.keys() |> Enum.sort(),
         adjacency <- adjacency(edges),
         parents <- parents(edges),
         paths <- canonical_paths(roots, adjacency, limits.depth),
         cycles <- cycle_edges(edges, adjacency, limits.nodes),
         {:ok, nodes} <-
           nodes(names, declarations, locks, parents, paths, cycles, resolver_attributes),
         :ok <- verify_closure(nodes, edges, reconciliation.lock_entries),
         gaps <- gaps(nodes, edges),
         evidence <- completeness(nodes, edges, reconciliation.lock_entries, gaps) do
      catalog = %{
        profile: @profile,
        repository_iri: attributes.repository_iri,
        tenant_iri: attributes.tenant_iri,
        edition_iri: attributes.edition_iri,
        source_fence: attributes.source_fence,
        reconciliation_digest: reconciliation.digest,
        nodes: nodes,
        edges: edges,
        roots: roots,
        cycles: cycles,
        gaps: gaps,
        completeness: evidence,
        node_count: length(nodes),
        edge_count: length(edges),
        maximum_depth: maximum_depth(nodes),
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      {:ok, Map.put(catalog, :digest, Contract.digest(catalog))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def resolve(_reconciliation, _attributes), do: invalid()

  defp validate(reconciliation, attributes, limits) do
    resources = [:repository_iri, :tenant_iri, :edition_iri]

    cond do
      reconciliation[:profile] != "mix-reconcile/1.0.0" or
          not Contract.digest?(reconciliation[:digest]) ->
        invalid()

      reconciliation[:source_fence] != attributes[:source_fence] ->
        conflict()

      not Enum.all?(resources, &(ResourceIdentity.validate(attributes[&1]) == :ok)) ->
        invalid()

      not valid_limits?(limits) ->
        invalid()

      not is_list(reconciliation[:declared_dependencies]) or
        not is_list(reconciliation[:observed_dependencies]) or
          not is_list(reconciliation[:lock_entries]) ->
        invalid()

      length(reconciliation.lock_entries) > limits.nodes ->
        invalid()

      true ->
        :ok
    end
  end

  defp declarations(reconciliation) do
    static = Map.new(reconciliation.declared_dependencies, &{&1.name, &1})

    observed =
      Map.new(reconciliation.observed_dependencies, fn value ->
        name = value["name"] || value[:name]
        {name, value}
      end)

    (Map.keys(static) ++ Map.keys(observed))
    |> Enum.uniq()
    |> Enum.sort()
    |> Map.new(fn name ->
      declared = static[name]
      observed_value = observed[name]

      {name,
       %{
         static: declared,
         observed: observed_value,
         conflict: declaration_conflict?(declared, observed_value)
       }}
    end)
  end

  defp declaration_conflict?(nil, _observed), do: false
  defp declaration_conflict?(_declared, nil), do: false

  defp declaration_conflict?(declared, observed) do
    observed_requirement = observed["requirement"] || observed[:requirement]
    observed_scm = observed["scm"] || observed[:scm]

    (is_binary(observed_requirement) and observed_requirement != declared.requirement) or
      (is_binary(observed_scm) and observed_scm != declared.scm)
  end

  defp edges(lock_entries, limits) do
    values =
      Enum.flat_map(lock_entries, fn entry ->
        Enum.map(entry.edges, fn edge ->
          %{
            parent: entry.name,
            child: edge.name,
            requirement: edge.requirement,
            optional: edge.optional,
            package: edge.package,
            repository: edge.repository,
            source: :lock
          }
        end)
      end)

    if length(values) <= limits.edges do
      unique = Enum.uniq_by(values, &{&1.parent, &1.child, &1.requirement, &1.optional})
      {:ok, Enum.sort_by(unique, &{&1.parent, &1.child, &1.requirement})}
    else
      invalid()
    end
  end

  defp names(declarations, locks, edges) do
    (Map.keys(declarations) ++ Map.keys(locks) ++ Enum.flat_map(edges, &[&1.parent, &1.child]))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp adjacency(edges) do
    edges
    |> Enum.group_by(& &1.parent, & &1.child)
    |> Map.new(fn {parent, children} -> {parent, children |> Enum.uniq() |> Enum.sort()} end)
  end

  defp parents(edges) do
    edges
    |> Enum.group_by(& &1.child, & &1.parent)
    |> Map.new(fn {child, values} -> {child, values |> Enum.uniq() |> Enum.sort()} end)
  end

  defp canonical_paths(roots, adjacency, maximum_depth) do
    queue = :queue.from_list(Enum.map(roots, &{&1, [&1]}))
    walk_paths(queue, %{}, adjacency, maximum_depth)
  end

  defp walk_paths(queue, paths, adjacency, maximum_depth) do
    case :queue.out(queue) do
      {{:value, {name, path}}, rest} ->
        cond do
          Map.has_key?(paths, name) ->
            walk_paths(rest, paths, adjacency, maximum_depth)

          length(path) > maximum_depth ->
            walk_paths(rest, paths, adjacency, maximum_depth)

          true ->
            next =
              adjacency
              |> Map.get(name, [])
              |> Enum.reduce(rest, fn child, current ->
                :queue.in({child, path ++ [child]}, current)
              end)

            walk_paths(next, Map.put(paths, name, path), adjacency, maximum_depth)
        end

      {:empty, _rest} ->
        paths
    end
  end

  defp cycle_edges(edges, adjacency, node_limit) do
    edges
    |> Enum.filter(fn edge -> reachable?(edge.child, edge.parent, adjacency, node_limit) end)
    |> Enum.map(&%{from: &1.parent, to: &1.child})
    |> Enum.sort_by(&{&1.from, &1.to})
  end

  defp reachable?(start, target, adjacency, node_limit) do
    reachable?([start], target, adjacency, MapSet.new(), node_limit)
  end

  defp reachable?([], _target, _adjacency, _visited, _node_limit), do: false

  defp reachable?([target | _rest], target, _adjacency, _visited, _node_limit), do: true

  defp reachable?([current | rest], target, adjacency, visited, node_limit) do
    cond do
      MapSet.size(visited) > node_limit ->
        false

      MapSet.member?(visited, current) ->
        reachable?(rest, target, adjacency, visited, node_limit)

      true ->
        next = Map.get(adjacency, current, []) ++ rest
        reachable?(next, target, adjacency, MapSet.put(visited, current), node_limit)
    end
  end

  defp nodes(names, declarations, locks, parents, paths, cycles, attributes) do
    cycle_names = cycles |> Enum.flat_map(&[&1.from, &1.to]) |> MapSet.new()

    Enum.reduce_while(names, {:ok, []}, fn name, {:ok, result} ->
      declaration = declarations[name]
      lock = locks[name]
      parent_names = Map.get(parents, name, [])
      path = paths[name]
      classification = classification(declaration, lock, parent_names, path)

      with {:ok, iri} <-
             ResourceIdentity.deterministic(
               :wiki_dependency_use,
               Enum.join([attributes.repository_iri, attributes.edition_iri, name], "\n")
             ) do
        node = %{
          iri: iri,
          name: name,
          roles: roles(declaration, parent_names, path),
          classification: classification,
          scm: scm(declaration, lock),
          requirement: declaration_value(declaration, :requirement),
          selected_version: if(lock, do: lock[:version], else: nil),
          selected_revision: if(lock, do: lock[:revision], else: nil),
          identity: if(lock, do: lock[:identity], else: nil),
          managers: if(lock, do: lock[:managers] || [], else: []),
          environments: declaration_value(declaration, :environments) || [],
          targets: declaration_value(declaration, :targets) || [],
          optional: declaration_value(declaration, :optional) || false,
          override: declaration_value(declaration, :override) || false,
          runtime: declaration_runtime(declaration),
          source_options: declaration_value(declaration, :options) || %{},
          lock_options: if(lock, do: lock[:options] || %{}, else: %{}),
          declaration: if(declaration, do: declaration.static, else: nil),
          observation: if(declaration, do: declaration.observed, else: nil),
          lock: lock,
          parents: parent_names,
          canonical_path: path,
          depth: if(path, do: length(path) - 1, else: nil),
          cycle: MapSet.member?(cycle_names, name),
          provenance: %{
            source_fence: attributes.source_fence,
            reconciliation_digest: attributes.reconciliation_digest,
            declared: not is_nil(declaration),
            locked: not is_nil(lock)
          }
        }

        {:cont, {:ok, [node | result]}}
      else
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.sort_by(values, & &1.name)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp classification(%{conflict: true}, _lock, _parents, _path), do: :conflicting
  defp classification(_declaration, %{status: :unsupported}, _parents, _path), do: :unsupported

  defp classification(%{static: %{scm: scm}}, nil, _parents, _path)
       when scm in ["path", "umbrella", "git"],
       do: :declared_only

  defp classification(declaration, nil, _parents, _path) when not is_nil(declaration),
    do: :missing_lock

  defp classification(nil, nil, parents, _path) when parents != [], do: :unverifiable
  defp classification(nil, %{status: :supported}, _parents, nil), do: :orphaned_lock
  defp classification(nil, %{status: :supported}, _parents, _path), do: :locked_only
  defp classification(_declaration, %{status: :supported}, _parents, _path), do: :resolved
  defp classification(_declaration, _lock, _parents, _path), do: :declared_only

  defp roles(declaration, parents, path) do
    []
    |> maybe_role(not is_nil(declaration), :direct)
    |> maybe_role(parents != [] or (is_list(path) and length(path) > 1), :transitive)
  end

  defp maybe_role(values, true, role), do: values ++ [role]
  defp maybe_role(values, false, _role), do: values

  defp scm(declaration, lock) do
    declaration_value(declaration, :scm) || if(lock, do: lock.kind, else: "unknown")
  end

  defp declaration_value(nil, _key), do: nil

  defp declaration_value(declaration, key) do
    static = declaration.static
    observed = declaration.observed

    cond do
      is_map(static) -> static[key]
      is_map(observed) -> observed[Atom.to_string(key)] || observed[key]
      true -> nil
    end
  end

  defp declaration_runtime(nil), do: nil
  defp declaration_runtime(declaration), do: declaration_value(declaration, :runtime)

  defp verify_closure(nodes, edges, lock_entries) do
    names = Enum.map(nodes, & &1.name)
    lock_names = Enum.map(lock_entries, & &1.name)

    cond do
      length(names) != length(Enum.uniq(names)) -> invalid()
      not Enum.all?(lock_names, &(&1 in names)) -> invalid()
      not Enum.all?(edges, &(&1.parent in names and &1.child in names)) -> invalid()
      true -> :ok
    end
  end

  defp gaps(nodes, edges) do
    node_gaps =
      nodes
      |> Enum.filter(&(&1.classification not in [:resolved, :locked_only, :orphaned_lock]))
      |> Enum.map(fn node ->
        %{
          kind: node.classification,
          dependency: node.name,
          blocking:
            node.classification in [:missing_lock, :unverifiable, :conflicting, :unsupported]
        }
      end)

    cycle_gaps =
      if Enum.any?(nodes, & &1.cycle),
        do: [%{kind: :cycle, dependency: nil, blocking: false}],
        else: []

    missing_edges =
      edges
      |> Enum.filter(fn edge ->
        node = Enum.find(nodes, &(&1.name == edge.child))
        node.classification == :unverifiable
      end)
      |> Enum.map(&%{kind: :unverifiable_edge, dependency: &1.child, blocking: true})

    (node_gaps ++ cycle_gaps ++ missing_edges)
    |> Enum.uniq()
    |> Enum.sort_by(&{to_string(&1.kind), &1.dependency || ""})
  end

  defp completeness(nodes, edges, lock_entries, gaps) do
    blocking = Enum.count(gaps, & &1.blocking)

    %{
      state: if(blocking == 0, do: :complete, else: :partial),
      represented_lock_nodes: Enum.count(nodes, &(&1.lock != nil)),
      expected_lock_nodes: length(lock_entries),
      represented_edges: length(edges),
      supported_edges: length(edges),
      direct_nodes: Enum.count(nodes, &(:direct in &1.roles)),
      transitive_nodes: Enum.count(nodes, &(:transitive in &1.roles)),
      orphaned_nodes: Enum.count(nodes, &(&1.classification == :orphaned_lock)),
      blocking_gap_count: blocking
    }
  end

  defp maximum_depth(nodes) do
    nodes |> Enum.map(&(&1.depth || 0)) |> Enum.max(fn -> 0 end)
  end

  defp valid_limits?(limits) when is_map(limits) do
    Enum.all?(@maximums, fn {key, maximum} ->
      value = limits[key]
      is_integer(value) and value > 0 and value <= maximum
    end)
  end

  defp valid_limits?(_limits), do: false

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_dependency_resolve)}
  defp conflict, do: {:error, Error.new(:conflict, :repository_wiki_dependency_resolve)}
end
