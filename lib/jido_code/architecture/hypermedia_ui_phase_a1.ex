defmodule JidoCode.Architecture.HypermediaUIPhaseA1 do
  @moduledoc false

  @manifest_directory "priv/architecture/hypermedia_ui"
  @baseline_manifest "phase_a1_authority_baseline.json"
  @runtime_manifest "phase_a1_runtime_inventory.json"
  @vocabulary_manifest "phase_a1_vocabulary_and_supersession.json"

  @required_terms ~w[
    factory tenant conceptual_repository project task attempt interaction_session
    candidate edition preview browser_session tab provider_thread runtime process agent
    page fragment projection signal stream hint patch command effect receipt evidence
    decision freshness readiness satisfaction
  ]

  @required_supersession_sources ~w[
    README.md
    assets/js/app.js
    docs/adr/0001-graph-only-source-of-truth.md
    docs/architecture/delegated-agent-phase-05-receipt.md
    docs/architecture/managed-coding-phase-04-receipt.md
    docs/architecture/module-boundaries.md
    docs/architecture/phase-10-receipt.md
    docs/architecture/product-security-privacy-and-threat-model.md
    docs/architecture/product-surface-and-island-contract.md
    docs/architecture/repository-wiki-product-and-qualification.md
    docs/operations/operator-handbook.md
    lib/jido_code_web/product_auth.ex
    lib/jido_code_web/router.ex
    mix.exs
    test/jido_code_web/live/home_live_test.exs
  ]

  @markdown_inventory ~w[
    docs/architecture/README.md
    docs/architecture/hypermedia-ui-current-state-authority-baseline.md
    docs/architecture/hypermedia-ui-milestone-a-phase-01-receipt.md
    docs/architecture/hypermedia-ui-runtime-and-authority-inventory.md
    docs/architecture/hypermedia-ui-vocabulary-and-supersession.md
    docs/planning/secure-hypermedia-control-plane-ui/README.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-a-architectural-authority/README.md
    docs/planning/secure-hypermedia-control-plane-ui/milestone-a-architectural-authority/phase-01-current-state-authority-and-gap-baseline.md
  ]

  @allowed_dispositions ~w[amend defer preserve supersede]
  @required_route_fields ~w[
    id method path pipelines owner state_owner authorization readiness
    replacement_disposition rollback_consequence tests operations
  ]
  @required_gap_fields ~w[
    id priority name owner blocking_gate status closure_evidence rollback_consequence
  ]
  @required_matrix_fields ~w[
    id source_path clause old_owner proposed_owner disposition target_phase
    migration_evidence rollback_dependency removal_phase status
  ]

  @type manifests :: %{baseline: map(), runtime: map(), vocabulary: map()}

  @spec check(Path.t()) :: {:ok, []} | {:error, [String.t()]}
  def check(root \\ File.cwd!()) do
    case load(root) do
      {:ok, manifests} ->
        case validate(manifests, root) do
          [] -> {:ok, []}
          errors -> {:error, errors}
        end

      {:error, errors} ->
        {:error, errors}
    end
  end

  @spec load(Path.t()) :: {:ok, manifests()} | {:error, [String.t()]}
  def load(root \\ File.cwd!()) do
    files = %{
      baseline: @baseline_manifest,
      runtime: @runtime_manifest,
      vocabulary: @vocabulary_manifest
    }

    {manifests, errors} =
      Enum.reduce(files, {%{}, []}, fn {key, file}, {loaded, errors} ->
        path = Path.join([root, @manifest_directory, file])

        case File.read(path) do
          {:ok, body} ->
            case Jason.decode(body) do
              {:ok, manifest} -> {Map.put(loaded, key, manifest), errors}
              {:error, reason} -> {loaded, ["#{path}: invalid JSON: #{inspect(reason)}" | errors]}
            end

          {:error, reason} ->
            {loaded, ["#{path}: cannot read manifest: #{inspect(reason)}" | errors]}
        end
      end)

    if errors == [], do: {:ok, manifests}, else: {:error, Enum.reverse(errors)}
  end

  @spec validate(manifests(), Path.t()) :: [String.t()]
  def validate(%{baseline: baseline, runtime: runtime, vocabulary: vocabulary}, root) do
    []
    |> validate_baseline(baseline, root)
    |> validate_runtime(runtime, root)
    |> validate_vocabulary(vocabulary, root)
    |> validate_markdown(root)
    |> Enum.reverse()
  end

  def validate(_incomplete, _root), do: ["HUI-A1 manifest set is incomplete"]

  defp validate_baseline(errors, baseline, root) do
    errors
    |> require_equal(baseline["schema_version"], 1, "authority baseline schema_version must be 1")
    |> require_sha(baseline["baseline"]["commit"], "authority baseline commit")
    |> validate_content_manifests(baseline, root)
    |> validate_pinned_files(baseline, root)
    |> validate_document_classes(baseline, root)
    |> validate_exceptions(baseline)
  end

  defp validate_content_manifests(errors, baseline, root) do
    commit = baseline["baseline"]["commit"]

    Enum.reduce(baseline["content_manifests"] || %{}, errors, fn {name, manifest}, acc ->
      roots = manifest["roots"] || []

      with {:ok, tree} <- git(root, ["ls-tree", "-r", commit, "--" | roots]),
           {:ok, names} <- git(root, ["ls-tree", "-r", "--name-only", commit, "--" | roots]) do
        digest = sha256(tree)
        count = names |> String.split("\n", trim: true) |> length()

        acc
        |> require_equal(
          digest,
          manifest["git_tree_digest"],
          "#{name} git-tree digest does not match the pinned baseline"
        )
        |> require_equal(
          count,
          manifest["entry_count"],
          "#{name} entry count does not match the pinned baseline"
        )
      else
        {:error, reason} -> ["cannot reproduce #{name} git tree: #{reason}" | acc]
      end
    end)
  end

  defp validate_pinned_files(errors, baseline, root) do
    commit = baseline["baseline"]["commit"]

    Enum.reduce(baseline["pinned_files"] || [], errors, fn pin, acc ->
      path = pin["path"]

      case git(root, ["show", "#{commit}:#{path}"]) do
        {:ok, body} ->
          require_equal(
            acc,
            sha256(body),
            pin["sha256"],
            "#{path} SHA-256 does not match the baseline Git blob"
          )

        {:error, reason} ->
          ["cannot read baseline blob #{path}: #{reason}" | acc]
      end
    end)
  end

  defp validate_document_classes(errors, baseline, root) do
    classes = baseline["governing_document_classes"] || []
    ids = Enum.map(classes, & &1["id"])

    errors =
      errors
      |> require_unique(ids, "governing document class id")
      |> require_nonempty(classes, "governing document classes are missing")

    Enum.reduce(classes, errors, fn class, acc ->
      acc =
        acc
        |> require_text(class["id"], "document class id")
        |> require_text(class["status"], "#{class["id"]} status")
        |> require_text(class["owner"], "#{class["id"]} owner")
        |> require_text(class["supersession_rule"], "#{class["id"]} supersession_rule")
        |> require_text(class["reopening_condition"], "#{class["id"]} reopening_condition")
        |> require_text(class["evidence"], "#{class["id"]} evidence")

      Enum.reduce(class["paths"] || [], acc, fn path, path_errors ->
        require_path(path_errors, root, path, "governing document")
      end)
    end)
  end

  defp validate_exceptions(errors, baseline) do
    exceptions = baseline["explicit_exceptions"] || []

    Enum.reduce(
      exceptions,
      require_nonempty(errors, exceptions, "explicit exceptions are missing"),
      fn exception, acc ->
        acc
        |> require_text(exception["id"], "exception id")
        |> require_text(exception["status"], "#{exception["id"]} status")
        |> require_text(exception["owner"], "#{exception["id"]} owner")
        |> require_text(exception["evidence"], "#{exception["id"]} evidence")
        |> require_text(exception["exit_gate"], "#{exception["id"]} exit_gate")
      end
    )
  end

  defp validate_runtime(errors, runtime, root) do
    routes = runtime["routes"] || []
    gaps = runtime["gaps"] || []
    semantic = runtime["semantic_surface"] || %{}

    errors =
      errors
      |> require_equal(runtime["schema_version"], 1, "runtime inventory schema_version must be 1")
      |> require_sha(runtime["baseline_commit"], "runtime inventory baseline commit")
      |> require_unique(Enum.map(routes, & &1["id"]), "route id")
      |> require_unique(Enum.map(gaps, & &1["id"]), "gap id")
      |> require_equal(
        length(routes),
        12,
        "runtime inventory must contain 11 product route records and the dashboard family"
      )
      |> require_equal(length(gaps), 24, "runtime inventory must own all 24 research gaps")
      |> require_equal(
        length(semantic["graph_families"] || []),
        semantic["graph_family_count"],
        "graph family count does not match graph_families"
      )
      |> require_equal(
        semantic["graph_family_count"],
        17,
        "graph family inventory must contain 17 families"
      )
      |> require_equal(
        semantic["semantic_command_count"],
        117,
        "semantic command inventory must contain 117 commands"
      )
      |> require_equal(
        semantic["reviewed_query_count"],
        158,
        "reviewed query inventory must contain 158 queries"
      )
      |> validate_gap_priorities(gaps)

    errors =
      Enum.reduce(routes, errors, fn route, acc ->
        acc = require_fields(acc, route, @required_route_fields, "route #{route["id"]}")

        acc
        |> validate_references(route["tests"], root, "route #{route["id"]} test")
        |> validate_references(route["operations"], root, "route #{route["id"]} operation")
      end)

    Enum.reduce(gaps, errors, fn gap, acc ->
      acc
      |> require_fields(gap, @required_gap_fields, "gap #{gap["id"]}")
      |> require_equal(gap["status"], "open", "gap #{gap["id"]} must remain open in HUI-A1")
    end)
  end

  defp validate_gap_priorities(errors, gaps) do
    counts = Enum.frequencies_by(gaps, & &1["priority"])

    errors
    |> require_equal(counts["P0"], 13, "P0 gap count must be 13")
    |> require_equal(counts["P1"], 9, "P1 gap count must be 9")
    |> require_equal(counts["P2"], 2, "P2 gap count must be 2")
  end

  defp validate_vocabulary(errors, vocabulary, root) do
    terms = vocabulary["terms"] || []
    rules = vocabulary["qualified_language_rules"] || []
    matrix = vocabulary["supersession_matrix"] || []
    term_names = Enum.map(terms, & &1["term"])
    source_paths = Enum.map(matrix, & &1["source_path"])

    errors =
      errors
      |> require_equal(vocabulary["schema_version"], 1, "vocabulary schema_version must be 1")
      |> require_sha(vocabulary["baseline_commit"], "vocabulary baseline commit")
      |> require_unique(term_names, "vocabulary term")
      |> require_unique(Enum.map(rules, & &1["token"]), "qualified language token")
      |> require_unique(Enum.map(matrix, & &1["id"]), "supersession id")
      |> require_equal(length(matrix), 17, "supersession matrix must contain 17 owned clauses")

    errors =
      Enum.reduce(@required_terms -- term_names, errors, fn term, acc ->
        ["required vocabulary term is missing: #{term}" | acc]
      end)

    errors =
      Enum.reduce(@required_supersession_sources -- source_paths, errors, fn path, acc ->
        ["required supersession source is missing: #{path}" | acc]
      end)

    errors =
      Enum.reduce(terms, errors, fn term, acc ->
        acc
        |> require_text(term["term"], "vocabulary term")
        |> require_text(term["kind"], "#{term["term"]} kind")
        |> require_text(term["definition"], "#{term["term"]} definition")
        |> require_text(term["authority_owner"], "#{term["term"]} authority_owner")
      end)

    Enum.reduce(matrix, errors, fn entry, acc ->
      acc
      |> require_fields(entry, @required_matrix_fields, "supersession #{entry["id"]}")
      |> require_in(
        entry["disposition"],
        @allowed_dispositions,
        "supersession #{entry["id"]} disposition is invalid"
      )
      |> require_path(root, entry["source_path"], "supersession source")
      |> require_contains(
        entry["target_phase"],
        "Milestone",
        "supersession #{entry["id"]} has no milestone owner"
      )
    end)
  end

  defp validate_markdown(errors, root) do
    Enum.reduce(@markdown_inventory, errors, fn relative_path, acc ->
      path = Path.join(root, relative_path)

      case File.read(path) do
        {:ok, body} ->
          body
          |> markdown_links()
          |> Enum.reduce(acc, fn target, link_errors ->
            validate_markdown_link(link_errors, root, relative_path, target)
          end)

        {:error, reason} ->
          ["cannot read Markdown inventory #{relative_path}: #{inspect(reason)}" | acc]
      end
    end)
  end

  defp markdown_links(body) do
    ~r/\[[^\]]*\]\(([^)]+)\)/
    |> Regex.scan(body, capture: :all_but_first)
    |> Enum.map(&List.first/1)
    |> Enum.reject(&external_link?/1)
  end

  defp validate_markdown_link(errors, root, source, target) do
    [path_part, anchor] =
      case String.split(target, "#", parts: 2) do
        [path] -> [path, nil]
        [path, fragment] -> [path, fragment]
      end

    relative_target =
      if path_part == "" do
        source
      else
        source
        |> Path.dirname()
        |> Path.join(path_part)
        |> Path.expand(root)
        |> Path.relative_to(root)
      end

    full_target = Path.join(root, relative_target)

    cond do
      not File.exists?(full_target) ->
        ["#{source}: Markdown target does not exist: #{target}" | errors]

      is_binary(anchor) and anchor != "" and not markdown_anchor?(full_target, anchor) ->
        ["#{source}: Markdown anchor does not exist: #{target}" | errors]

      true ->
        errors
    end
  end

  defp markdown_anchor?(path, anchor) do
    path
    |> File.read!()
    |> String.split("\n")
    |> Enum.filter(&String.match?(&1, ~r/^[#]{1,6}\s+/))
    |> Enum.map(&markdown_slug/1)
    |> Enum.member?(anchor)
  end

  defp markdown_slug(heading) do
    heading
    |> String.replace(~r/^[#]{1,6}\s+/, "")
    |> String.downcase()
    |> String.replace(~r/[^\p{L}\p{N}\s-]/u, "")
    |> String.trim()
    |> String.replace(~r/\s+/, "-")
  end

  defp external_link?(target),
    do:
      String.starts_with?(target, "http://") or String.starts_with?(target, "https://") or
        String.starts_with?(target, "mailto:")

  defp validate_references(errors, references, root, label) do
    Enum.reduce(references || [], errors, fn path, acc -> require_path(acc, root, path, label) end)
  end

  defp require_fields(errors, map, fields, label) do
    Enum.reduce(fields, errors, fn field, acc ->
      require_present(acc, map[field], "#{label} is missing #{field}")
    end)
  end

  defp require_path(errors, root, path, label) do
    if is_binary(path) and File.exists?(Path.join(root, path)),
      do: errors,
      else: ["#{label} does not exist: #{inspect(path)}" | errors]
  end

  defp require_present(errors, value, message) do
    if present?(value), do: errors, else: [message | errors]
  end

  defp require_text(errors, value, label) do
    require_present(errors, value, "#{label} must be non-empty text")
  end

  defp require_nonempty(errors, value, message) when is_list(value) do
    if value == [], do: [message | errors], else: errors
  end

  defp require_unique(errors, values, label) do
    duplicates = values -- Enum.uniq(values)

    Enum.reduce(Enum.uniq(duplicates), errors, fn value, acc ->
      ["duplicate #{label}: #{inspect(value)}" | acc]
    end)
  end

  defp require_equal(errors, actual, expected, message) do
    if actual == expected,
      do: errors,
      else: ["#{message}; expected #{inspect(expected)}, got #{inspect(actual)}" | errors]
  end

  defp require_in(errors, actual, allowed, message) do
    if actual in allowed, do: errors, else: [message | errors]
  end

  defp require_contains(errors, value, substring, message) do
    if is_binary(value) and String.contains?(value, substring),
      do: errors,
      else: [message | errors]
  end

  defp require_sha(errors, value, label) do
    if is_binary(value) and Regex.match?(~r/^[0-9a-f]{40}$/, value),
      do: errors,
      else: ["#{label} must be a full lowercase Git SHA" | errors]
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value), do: not is_nil(value)

  defp git(root, arguments) do
    case System.cmd("git", arguments, cd: root, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {output, _status} -> {:error, String.trim(output)}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp sha256(body),
    do: body |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end
