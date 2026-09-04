defmodule JidoCode.Architecture.HypermediaUIPhaseB4 do
  @moduledoc false

  alias JidoCode.Architecture.HypermediaUIPhaseB1
  alias JidoCode.Architecture.HypermediaUIPhaseB2
  alias JidoCode.Architecture.HypermediaUIPhaseB3

  @manifest_path "priv/architecture/hypermedia_ui/phase_b4_fitness_policy.json"
  @baseline "e14ee7fa268eb6bd5a4d7bb7e519cce748d7b5e2"
  @document_path "docs/architecture/hypermedia-ui-dependency-fitness-and-update-policy.md"
  @manifest_digests %{
    "priv/architecture/hypermedia_ui/phase_b1_candidate_bom.json" =>
      "dbfb08bfa5a95d41a538dadbcd8f9605918761a565e82ae075854c969a6f7f12",
    "priv/architecture/hypermedia_ui/phase_b1_supply_chain_ledger.json" =>
      "7e8c4286ebd125f0c1b8a8997abba699c82f0f583b5f518d0b6a7eeba9d9cfe6",
    "priv/architecture/hypermedia_ui/phase_b2_dependency_graph.json" =>
      "e35613aa0d39af166aa4156e284a0eeab6a68c720b8d186198b5ed0472fe622a",
    "priv/architecture/hypermedia_ui/phase_b2_resolved_sbom.json" =>
      "7a0b9e4ed1b4e187d464dae39de8e593978d9fa81a8b396619d848e14c697f68",
    "priv/architecture/hypermedia_ui/phase_b2_asset_pipeline.json" =>
      "de73f1008e64693583201b02b3fae50fd2c563d2fe38d61941a4a4b49806007a",
    "priv/architecture/hypermedia_ui/phase_b2_component_theme_contract.json" =>
      "381aa3d8c2b36113c97abf3df192a1614c04e9b40dd7720ae3a8636f884b46d4",
    "priv/architecture/hypermedia_ui/phase_b3_verification_evidence.json" =>
      "9acba10084866ab7d800c02b9fded59406b0370bffdad83dc973416f2a656344"
  }
  @candidate_inputs %{
    "mix.exs" => "d66c00f068f43943ed9bd94b0a2c77db152a224ad3e1d6deefee4745df3ffab9",
    "mix.lock" => "98b302693e9dbf826129aec7bdb85740201fb076096d253d10e4f7ba1660e10b",
    "package.json" => "d41b1362235934cf2f37a87351f1610325e27945660b636619b3f49a2fdc51ba",
    "package-lock.json" => "8a4b2384bdaf539731dd7eefa169cacaea38bcf689c2a59108ff6de5456addda",
    "assets/vendor/datastar/datastar.js" =>
      "5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65",
    "deps/shadcn_ui/priv/static/shadcn_ui.css" =>
      "ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41"
  }
  @hex_pins %{
    "dstar" => "0.2.0",
    "phoenix" => "1.8.11",
    "phoenix_html" => "4.3.0",
    "phoenix_live_view" => "1.2.9",
    "salad_ui" => "1.0.0"
  }
  @source_pins %{
    "shadcn_ui" => "fe40eae63504adc4375aead4f0e741f158a4d86e",
    "datastar" => "73ab00e7c06d8c2bad030fdddafba800fcccbde2"
  }
  @npm_pins %{
    "@playwright/test" => "1.62.0",
    "@tailwindcss/vite" => "4.3.3",
    "tailwindcss" => "4.3.3",
    "vite" => "7.3.6"
  }
  @forbidden ~w[
    mutable_hui_source remote_or_cdn_product_asset unreviewed_hui_override_or_fork
    unexpected_hui_transitive_application shadcn_import_outside_facade
    new_liveview_product_runtime new_livevue_or_vue_consumer new_saladui_consumer
    dstar_scripts inline_or_eval_csp_weakening browser_authority
    unapproved_network_or_build_step
  ]
  @update_evidence ~w[
    immutable_provenance license_and_usage_authority advisory_scan
    dependency_and_consumer_diff browser_protocol_matrix manual_accessibility_review
    release_and_rollback_drill
  ]

  @spec check(Path.t()) :: {:ok, []} | {:error, [String.t()]}
  def check(root \\ File.cwd!()) do
    predecessor_errors =
      [HypermediaUIPhaseB1, HypermediaUIPhaseB2, HypermediaUIPhaseB3]
      |> Enum.flat_map(fn module -> module.check(root) |> errors() end)

    with {:ok, policy} <- load(root) do
      case predecessor_errors ++ validate(policy, root) do
        [] -> {:ok, []}
        errors -> {:error, errors}
      end
    end
  end

  @spec load(Path.t()) :: {:ok, map()} | {:error, [String.t()]}
  def load(root \\ File.cwd!()) do
    path = Path.join(root, @manifest_path)

    with {:ok, body} <- File.read(path),
         {:ok, policy} <- Jason.decode(body) do
      {:ok, policy}
    else
      {:error, %Jason.DecodeError{} = reason} ->
        {:error, ["#{path}: invalid JSON: #{Exception.message(reason)}"]}

      {:error, reason} ->
        {:error, ["#{path}: unavailable policy: #{inspect(reason)}"]}
    end
  end

  @spec validate(map(), Path.t()) :: [String.t()]
  def validate(policy, root) when is_map(policy) do
    stack = policy["approved_stack"] || %{}
    consumers = policy["approved_consumers"] || %{}

    []
    |> require_equal(policy["schema_version"], 1, "schema_version")
    |> require_equal(policy["phase"], "HUI-B4", "phase")
    |> require_equal(policy["status"], "fitness_policy_installed", "policy status")
    |> require_equal(policy["baseline_commit"], @baseline, "baseline")
    |> require_equal(policy["input_manifest_digests"], @manifest_digests, "manifest pins")
    |> require_equal(policy["candidate_inputs"], @candidate_inputs, "candidate pins")
    |> require_equal(stack["hex"], @hex_pins, "Hex pins")
    |> require_equal(stack["source"], @source_pins, "source pins")
    |> require_equal(stack["npm"], @npm_pins, "npm pins")
    |> require_exact_set(stack["licenses"] || [], ~w[Apache-2.0 MIT], "license allowlist")
    |> require_equal(consumers["product_consumers"], [], "product consumer boundary")
    |> require_exact_set(policy["forbidden_capabilities"] || [], @forbidden, "forbidden rules")
    |> require_exact_set(policy["update_evidence"] || [], @update_evidence, "update evidence")
    |> require_equal(policy["exceptions"], [], "fitness exceptions")
    |> validate_digests(root, @manifest_digests)
    |> validate_digests(root, @candidate_inputs)
    |> validate_current_sources(root)
    |> validate_document(root)
    |> Enum.reverse()
  end

  def validate(_policy, _root), do: ["HUI-B4 fitness policy must be a map"]

  @spec check_candidate_sources([{String.t(), String.t()}]) :: [String.t()]
  def check_candidate_sources(sources) when is_list(sources) do
    Enum.flat_map(sources, fn {path, source} ->
      [
        {Regex.match?(~r/\bDstar\.Scripts\b/, source), "#{path}: Dstar Scripts is prohibited"},
        {Path.extname(path) == ".heex" and Regex.match?(~r/<script(?:\s|>)/i, source),
         "#{path}: inline scripts are prohibited"},
        {Regex.match?(~r/(?:unsafe-eval|unsafe-inline)/, source),
         "#{path}: unsafe CSP evaluation is prohibited"},
        {Regex.match?(
           ~r/(?:<(?:script|link)[^>]+(?:src|href)=[\"']https?:\/\/|@import\s+(?:url\()?['\"]?https?:\/\/)/i,
           source
         ), "#{path}: remote or CDN product assets are prohibited"},
        {Regex.match?(
           ~r/(?:localStorage|sessionStorage|signals?)[^\n]{0,160}(?:grant|authority|assurance|delegation|policy_revision|expected_revision)/i,
           source
         ), "#{path}: browser state cannot supply authority"}
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp validate_current_sources(errors, root) do
    sources =
      ["lib/jido_code_web/**/*.ex", "lib/jido_code_web/**/*.heex", "assets/js/**/*.js"]
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.uniq()
      |> Enum.filter(&File.regular?/1)
      |> Enum.reject(&(Path.relative_to(&1, root) == "assets/vendor/datastar/datastar.js"))
      |> Enum.map(&{Path.relative_to(&1, root), File.read!(&1)})

    Enum.reverse(check_candidate_sources(sources)) ++ errors
  end

  defp validate_document(errors, root) do
    body = read(root, @document_path)

    errors
    |> require_contains(body, "Deterministic Update Workflow", "update workflow")
    |> require_contains(body, "accessibility, release-startup", "accessibility renewal")
    |> require_contains(body, "release-startup", "release renewal")
    |> require_contains(body, "rollback", "rollback renewal")
    |> require_contains(body, "reopens HUI2", "drift reopening")
  end

  defp validate_digests(errors, root, expected) do
    Enum.reduce(expected, errors, fn {path, digest}, acc ->
      case File.read(Path.join(root, path)) do
        {:ok, body} -> require_equal(acc, sha256(body), digest, "digest #{path}")
        {:error, reason} -> ["#{path}: unavailable input: #{inspect(reason)}" | acc]
      end
    end)
  end

  defp require_equal(errors, actual, expected, _label) when actual == expected, do: errors

  defp require_equal(errors, actual, expected, label),
    do: ["#{label}: expected #{inspect(expected)}, got #{inspect(actual)}" | errors]

  defp require_exact_set(errors, actual, expected, label) do
    if MapSet.new(actual) == MapSet.new(expected),
      do: errors,
      else: ["#{label} is not exact" | errors]
  end

  defp require_contains(errors, body, fragment, label) do
    if String.contains?(body, fragment), do: errors, else: ["missing #{label}" | errors]
  end

  defp errors({:ok, []}), do: []
  defp errors({:error, errors}), do: errors
  defp read(root, path), do: File.read!(Path.join(root, path))
  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
end
