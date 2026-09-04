defmodule JidoCode.Architecture.HypermediaUIPhaseB2 do
  @moduledoc false

  alias JidoCodeWeb.Plugs.ContentSecurityPolicy

  @manifest_directory "priv/architecture/hypermedia_ui"
  @manifest_files %{
    graph: "phase_b2_dependency_graph.json",
    sbom: "phase_b2_resolved_sbom.json",
    theme: "phase_b2_component_theme_contract.json",
    assets: "phase_b2_asset_pipeline.json",
    evidence: "phase_b2_verification_evidence.json"
  }
  @baseline "da9776d49d9e2f9d487294292e7643355576902d"
  @plan_path "docs/planning/secure-hypermedia-control-plane-ui/milestone-b-dependency-and-consumer-proof/phase-02-phoenix-component-and-asset-integration.md"
  @receipt_path "docs/architecture/hypermedia-ui-milestone-b-phase-02-receipt.md"
  @facade_path "lib/jido_code_web/components/ui.ex"
  @hui_b3_qualification_consumer_paths MapSet.new(~w[
    lib/jido_code_web/controllers/qualification/hypermedia_controller.ex
    lib/jido_code_web/qualification/hypermedia_stream_fixture.ex
  ])
  @authorized_legacy_paths ~w[
    mix.exs
    lib/jido_code_web/endpoint.ex
    lib/jido_code_web/components/ui.ex
    lib/jido_code_web/components/layouts.ex
    lib/jido_code_web/live/coding_agent_live.ex
    assets/js/app.js
    assets/css/app.css
    assets/vite.config.mjs
  ]
  @primitive_names ~w[button field_input link badge table disclosure dialog status]
  @component_names ~w[
    phoenix phoenix_html phoenix_live_view phoenix_pubsub phoenix_template plug plug_crypto
    jason telemetry mime websock_adapter websock spitfire dstar shadcn_ui salad_ui
    @tailwindcss/vite tailwindcss vite
  ]
  @direct_constraints %{
    "phoenix" => "== 1.8.11",
    "phoenix_html" => "== 4.3.0",
    "phoenix_live_view" => "== 1.2.9",
    "shadcn_ui" => "git:fe40eae63504adc4375aead4f0e741f158a4d86e",
    "dstar" => "== 0.2.0",
    "salad_ui" => "== 1.0.0"
  }
  @retained_transitives %{
    "phoenix_pubsub" => "2.2.0",
    "phoenix_template" => "1.0.4",
    "plug" => "1.20.3",
    "plug_crypto" => "2.2.0",
    "jason" => "1.4.5",
    "spitfire" => "0.4.0"
  }
  @component_contracts %{
    "phoenix" =>
      {"1.8.11", "MIT", "44f028f4129e5a29487e868f84903373e3d032da151ad0c789c3849f464e7351"},
    "phoenix_html" =>
      {"4.3.0", "MIT", "3eaa290a78bab0f075f791a46a981bbe769d94bc776869f4f3063a14f30497ad"},
    "phoenix_live_view" =>
      {"1.2.9", "MIT", "2f9528c3d7046edabbb30a91710ca33988f8d8bc20a964a1fc48b32134572afa"},
    "phoenix_pubsub" =>
      {"2.2.0", "MIT", "adc313a5bf7136039f63cfd9668fde73bba0765e0614cba80c06ac9460ff3e96"},
    "phoenix_template" =>
      {"1.0.4", "MIT", "2c0c81f0e5c6753faf5cca2f229c9709919aba34fab866d3bc05060c9c444206"},
    "plug" =>
      {"1.20.3", "Apache-2.0", "be266aee1b8536ef6409d58cf39a3121319f0ec47cfa1b24024485aa0e76ad76"},
    "plug_crypto" =>
      {"2.2.0", "Apache-2.0", "83a95744ab1c75876542b6fab135fcc176280e0f301a111c1f757fddcec95d2c"},
    "jason" =>
      {"1.4.5", "Apache-2.0", "b0c823996102bcd0239b3c2444eb00409b72f6a140c1950bc8b457d836b30684"},
    "telemetry" =>
      {"1.4.2", "Apache-2.0", "928f6495066506077862c0d1646609eed891a4326bee3126ba54b60af61febb1"},
    "mime" =>
      {"2.0.7", "Apache-2.0", "6171188e399ee16023ffc5b76ce445eb6d9672e2e241d2df6050f3c771e80ccd"},
    "websock_adapter" =>
      {"0.6.0", "MIT", "50021a85bce8f203b086705d9e0c5415e2c7eb05d319111b0428fe71f9934617"},
    "websock" =>
      {"0.5.3", "MIT", "6105453d7fac22c712ad66fab1d45abdf049868f253cf719b625151460b8b453"},
    "spitfire" =>
      {"0.4.0", "Apache-2.0", "7e5c6d1523c111b59f332f9dc49edc0377111d0c17167a29830f0e98233f5472"},
    "dstar" =>
      {"0.2.0", "MIT", "4766c1f3da802aa7e842aa78cbb778c8d764599e18fc67bbe32fbe25ac2c6460"},
    "shadcn_ui" => {"1.0.0+fe40eae63504", "MIT", "fe40eae63504adc4375aead4f0e741f158a4d86e"},
    "salad_ui" =>
      {"1.0.0", "MIT", "4cc5811d7be5ef3ff84b99d0741ffdc0a75bc6aa05298802a45d5640f307beac"},
    "@tailwindcss/vite" =>
      {"4.3.3", "MIT",
       "sha512-yYU8cogLeSh/ms2jh8Fj7jaba/EWa7Ja6GoUqYZaraEuCI5YS6ms6ObZgjjedm+jm6XZjdNRWBpPP6Z86oOxcw=="},
    "tailwindcss" =>
      {"4.3.3", "MIT",
       "sha512-gOhV3P7ufE62QDGg1zVaTgCR+EtPv92k2nIhVcVKcLmxT1sUBsQGhnZj175j+MqRt4zLF7ic+sCYjfhxMxj7YQ=="},
    "vite" =>
      {"7.3.6", "MIT",
       "sha512-4XP60spRGjSZFf1qYH+dJIkK2znL3zQfl9KkOV9MkkRR/3Dls0dxaBsQPTloEc5BLXWPL9vsOxopxyKoMmDueg=="}
  }
  @source_hashes %{
    "mix.exs" => "d66c00f068f43943ed9bd94b0a2c77db152a224ad3e1d6deefee4745df3ffab9",
    "mix.lock" => "cb1db44c1cc488f7e8a8e9caba7b52ac68977666b28c8e515f24114c43407644",
    "package.json" => "7f591835bbd701538c7352dcbc54b7f6e9f8930b94ded856bb67128023b48da3",
    "package-lock.json" => "fc388ab416c696007dc3f15fda8ac4a2e897bf63ac78440019eab1f94f9351c7",
    "assets/js/app.js" => "5f3451073941a412f73af51f3808b9530cbed20e8b83776c05c99ab4a4f65d4d",
    "assets/css/app.css" => "3920d1b157fea16475fda56ca07d463e6238c26e8b987485b9460f261c68ef58",
    "assets/js/theme.js" => "b61046bdcc7a7164d419d1658c0dedd13a9b26ae057c736d01e49832e931850a",
    "assets/vite.config.mjs" =>
      "8dce1648c67860f48c3cf4df10fa02bc0e9053f7c811646ef988c3e3309d22d8",
    @facade_path => "c6a537da7828a9357e15c0e72a9ba3196429c7e23a31dd76ac303dc17b5528e5",
    "lib/jido_code_web/plugs/content_security_policy.ex" =>
      "cc99a36283d7705263ef3b0629e20ab1ca2a19b845ebc9c89698f4eac6e35ab6",
    "lib/jido_code/architecture/hypermedia_ui_phase_a4.ex" =>
      "6e2d947e4aa29273673a1f94560591732373d2270718288898e94b77ce23b2a0",
    "lib/jido_code_web/live/coding_agent_live.ex" =>
      "a221cff02288043219bc6eabf7aa94f342738b376132f16279655b3e092e3a50",
    "assets/vendor/datastar/datastar.js" =>
      "5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65"
  }
  @required_documents ~w[
    docs/architecture/hypermedia-ui-phoenix-component-resolution.md
    docs/architecture/hypermedia-ui-component-facade-and-theme.md
    docs/architecture/hypermedia-ui-datastar-asset-pipeline.md
    docs/architecture/hypermedia-ui-milestone-b-phase-02-receipt.md
  ]
  @negative_case_ids ~w[
    dependency_pin_drift lock_checksum_drift implicit_override missing_license
    shadcn_outside_facade datastar_product_consumer dstar_product_consumer
    bundle_digest_drift source_map_present csp_unsafe_eval csp_unsafe_inline
    missing_or_reused_nonce nondeterministic_build mixed_closure_state
  ]

  @type manifests :: %{
          graph: map(),
          sbom: map(),
          theme: map(),
          assets: map(),
          evidence: map()
        }

  @spec check(Path.t()) :: {:ok, []} | {:error, [String.t()]}
  def check(root \\ File.cwd!()) do
    with {:ok, manifests} <- load(root) do
      case validate(manifests, root) do
        [] -> {:ok, []}
        errors -> {:error, errors}
      end
    end
  end

  @spec load(Path.t()) :: {:ok, manifests()} | {:error, [String.t()]}
  def load(root \\ File.cwd!()) do
    {manifests, errors} =
      Enum.reduce(@manifest_files, {%{}, []}, fn {key, filename}, {loaded, errors} ->
        path = Path.join([root, @manifest_directory, filename])

        with {:ok, body} <- File.read(path),
             {:ok, manifest} <- Jason.decode(body) do
          {Map.put(loaded, key, manifest), errors}
        else
          {:error, %Jason.DecodeError{} = reason} ->
            {loaded, ["#{path}: invalid JSON: #{Exception.message(reason)}" | errors]}

          {:error, reason} ->
            {loaded, ["#{path}: unavailable manifest: #{inspect(reason)}" | errors]}
        end
      end)

    if errors == [], do: {:ok, manifests}, else: {:error, Enum.reverse(errors)}
  end

  @spec validate(manifests(), Path.t()) :: [String.t()]
  def validate(
        %{graph: graph, sbom: sbom, theme: theme, assets: assets, evidence: evidence},
        root
      ) do
    []
    |> validate_graph(graph)
    |> validate_sbom(sbom)
    |> validate_theme(theme)
    |> validate_assets(assets)
    |> validate_evidence(evidence)
    |> validate_lifecycle(graph, evidence, root)
    |> validate_sources(root)
    |> validate_documents(root)
    |> validate_closure_files(root)
    |> Enum.reverse()
  end

  def validate(_incomplete, _root), do: ["HUI-B2 manifest set is incomplete"]

  @spec check_product_sources([{String.t(), String.t()}]) :: [String.t()]
  def check_product_sources(sources) do
    sources
    |> Enum.flat_map(fn {path, source} ->
      [
        {
          Enum.all?([
            path != @facade_path,
            Regex.match?(~r/(?:use|import|alias)\s+ShadcnUI|ShadcnUI\./, source)
          ]),
          "#{path}: ShadcnUI is available only behind #{@facade_path}"
        },
        {
          not MapSet.member?(@hui_b3_qualification_consumer_paths, path) and
            Regex.match?(
              ~r/\bDstar\.(?:Page|Router|Component|Plugs|Scripts|SSE|Utility)/,
              source
            ),
          "#{path}: Dstar product consumption is not authorized in HUI-B2"
        },
        {
          Enum.all?([
            not MapSet.member?(@hui_b3_qualification_consumer_paths, path),
            Path.extname(path) in [".ex", ".heex"],
            Regex.match?(~r/data-on:/, source)
          ]),
          "#{path}: Datastar product expressions are not authorized in HUI-B2"
        },
        {
          Regex.match?(~r/(?:import|from)\s+["']https?:\/\//, source),
          "#{path}: remote product asset import is prohibited"
        }
      ]
      |> Enum.filter(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @spec validate_closure(String.t(), String.t()) :: [String.t()]
  def validate_closure(plan, receipt) do
    accepted? = String.contains?(receipt, "Status: **accepted-at-merged-candidate**")
    pending? = String.contains?(receipt, "Status: **merge-pending**")

    cond do
      accepted? and not pending? ->
        []
        |> require_contains(plan, "status: completed", "HUI-B2 completed plan status")
        |> require_checkbox(plan, "2", "Phase", true)
        |> require_checkbox(plan, "2.4", "Section", true)
        |> require_checkbox(plan, "2.4.2", "Task", true)
        |> require_checkbox(plan, "2.4.2.3", "Subtask", true)
        |> require_match(receipt, ~r/Merged candidate: `[0-9a-f]{40}`/, "merged candidate")
        |> require_match(receipt, ~r/Merge date: `\d{4}-\d{2}-\d{2}`/, "merge date")

      pending? and not accepted? ->
        []
        |> require_contains(plan, "status: proposed", "HUI-B2 proposed plan status")
        |> require_checkbox(plan, "2", "Phase", false)
        |> require_checkbox(plan, "2.4", "Section", false)
        |> require_checkbox(plan, "2.4.2", "Task", false)
        |> require_checkbox(plan, "2.4.2.3", "Subtask", false)
        |> require_contains(plan, "- [x] 2.4.1 Task", "HUI-B2 integration task")
        |> require_contains(plan, "- [x] 2.4.2.1 Subtask", "HUI-B2 pending rule")
        |> require_contains(plan, "- [x] 2.4.2.2 Subtask", "HUI-B2 evidence task")
        |> require_contains(receipt, "Merged candidate: `merge-pending`", "pending candidate")
        |> require_contains(receipt, "Merge date: `merge-pending`", "pending merge date")

      true ->
        ["HUI-B2 closure must have exactly one coherent receipt state"]
    end
  end

  defp validate_graph(errors, graph) do
    errors
    |> require_equal(graph["schema_version"], 1, "dependency graph schema_version")
    |> require_equal(graph["phase"], "HUI-B2", "dependency graph phase")
    |> require_equal(graph["baseline_commit"], @baseline, "dependency graph baseline")
    |> require_member(
      graph["status"],
      ["integration_candidate_merge_pending", "accepted_at_merged_candidate"],
      "dependency graph status"
    )
    |> require_equal(graph["direct_constraints"], @direct_constraints, "direct constraints")
    |> require_equal(
      graph["retained_transitive_resolutions"],
      @retained_transitives,
      "retained transitive resolutions"
    )
    |> require_exact_set(
      graph["authorized_legacy_exception_paths"],
      @authorized_legacy_paths,
      "authorized legacy exception paths"
    )
    |> require_equal(graph["exceptions"], [], "dependency exceptions")
    |> require_equal(
      get_in(graph, ["application_loading", "new_liveview_product_consumers"]),
      false,
      "LiveView product consumer boundary"
    )
    |> require_equal(
      get_in(graph, ["application_loading", "dstar_stream_registry_started_by_jido_code"]),
      false,
      "Dstar StreamRegistry boundary"
    )
  end

  defp validate_sbom(errors, sbom) do
    components = sbom["components"] || []
    assets = sbom["assets"] || []

    errors =
      errors
      |> require_equal(sbom["schema_version"], 1, "resolved SBOM schema_version")
      |> require_equal(sbom["phase"], "HUI-B2", "resolved SBOM phase")
      |> require_equal(
        sbom["status"],
        "exact_dependency_and_asset_graph_resolved",
        "resolved SBOM status"
      )
      |> require_equal(
        sbom["lock_sha256"],
        @source_hashes["mix.lock"],
        "resolved SBOM lock digest"
      )
      |> require_exact_set(
        Enum.map(components, & &1["name"]),
        @component_names,
        "SBOM components"
      )
      |> require_exact_set(
        Enum.map(assets, & &1["name"]),
        ~w[shadcn_ui.css datastar.js],
        "SBOM assets"
      )
      |> require_equal(sbom["exceptions"], [], "SBOM exceptions")

    errors =
      Enum.reduce(components, errors, fn component, acc ->
        case Map.fetch(@component_contracts, component["name"]) do
          {:ok, {version, license, integrity}} ->
            acc
            |> require_equal(component["version"], version, "#{component["name"]} version")
            |> require_equal(component["license"], license, "#{component["name"]} license")
            |> require_equal(
              component["integrity"],
              integrity,
              "#{component["name"]} integrity"
            )

          :error ->
            ["unknown SBOM component contract: #{inspect(component["name"])}" | acc]
        end
      end)

    Enum.reduce(assets, errors, fn component, acc ->
      acc
      |> require_present(component["version"], "#{component["name"]} version")
      |> require_present(component["license"], "#{component["name"]} license")
      |> require_present(
        component["integrity"] || component["sha256"],
        "#{component["name"]} integrity"
      )
    end)
  end

  defp validate_theme(errors, theme) do
    errors
    |> require_equal(theme["schema_version"], 1, "component/theme schema_version")
    |> require_equal(theme["phase"], "HUI-B2", "component/theme phase")
    |> require_equal(theme["status"], "qualified_facade_and_theme", "component/theme status")
    |> require_exact_set(
      get_in(theme, ["facade", "public_primitives"]) || [],
      @primitive_names,
      "facade primitive names"
    )
    |> require_equal(
      get_in(theme, ["facade", "module"]),
      "JidoCodeWeb.Components.UI",
      "facade module"
    )
    |> require_equal(
      get_in(theme, ["facade", "authority_from_component_attrs"]),
      false,
      "component authority boundary"
    )
    |> require_equal(
      get_in(theme, ["facade", "broad_upstream_imports_allowed"]),
      false,
      "broad ShadcnUI imports"
    )
    |> require_equal(
      get_in(theme, ["stylesheet", "sha256"]),
      "ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41",
      "ShadcnUI stylesheet digest"
    )
    |> require_equal(
      get_in(theme, ["stylesheet", "remote_fallback"]),
      false,
      "ShadcnUI remote fallback"
    )
    |> require_equal(theme["exceptions"], [], "component/theme exceptions")
  end

  defp validate_assets(errors, assets) do
    errors
    |> require_equal(assets["schema_version"], 1, "asset pipeline schema_version")
    |> require_equal(assets["phase"], "HUI-B2", "asset pipeline phase")
    |> require_equal(
      assets["status"],
      "qualified_deterministic_local_pipeline",
      "asset pipeline status"
    )
    |> require_equal(
      get_in(assets, ["datastar", "sha256"]),
      @source_hashes["assets/vendor/datastar/datastar.js"],
      "Datastar bundle digest"
    )
    |> require_equal(get_in(assets, ["datastar", "bytes"]), 33_538, "Datastar byte size")
    |> require_equal(get_in(assets, ["datastar", "version"]), "1.0.3", "Datastar version")
    |> require_equal(
      get_in(assets, ["datastar", "source_commit"]),
      "73ab00e7c06d8c2bad030fdddafba800fcccbde2",
      "Datastar source commit"
    )
    |> require_equal(
      get_in(assets, ["datastar", "source_map_shipped"]),
      false,
      "Datastar source-map policy"
    )
    |> require_equal(
      get_in(assets, ["build", "repeat_builds_equal"]),
      true,
      "deterministic build result"
    )
    |> require_equal(get_in(assets, ["build", "map_files"]), [], "production map files")
    |> require_equal(
      get_in(assets, ["build", "vite_manifest_sha256"]),
      "c3cf4c4bfcb85020c8950a327074bdfcf494e6c5829976cdff59dec42c25a75c",
      "Vite manifest digest"
    )
    |> require_equal(
      get_in(assets, ["build", "phoenix_manifest_sha256"]),
      "44722d5ec867aba8c78692430d0b8ce7a746603d48017416b87ab858e7ce3673",
      "Phoenix manifest digest"
    )
    |> require_equal(
      get_in(assets, ["consumer_boundary", "product_datastar_attributes"]),
      false,
      "Datastar product consumer boundary"
    )
    |> require_equal(
      get_in(assets, ["consumer_boundary", "dstar_product_modules"]),
      false,
      "Dstar product consumer boundary"
    )
    |> require_equal(assets["exceptions"], [], "asset exceptions")
  end

  defp validate_evidence(errors, evidence) do
    cases = evidence["negative_cases"] || []

    errors
    |> require_equal(evidence["schema_version"], 1, "verification evidence schema_version")
    |> require_equal(evidence["phase"], "HUI-B2", "verification evidence phase")
    |> require_member(
      evidence["status"],
      ["integration_candidate_merge_pending", "accepted_at_merged_candidate"],
      "verification evidence status"
    )
    |> require_equal(evidence["baseline_commit"], @baseline, "verification evidence baseline")
    |> require_exact_set(Enum.map(cases, & &1["id"]), @negative_case_ids, "negative cases")
    |> require_equal(
      Enum.uniq(Enum.map(cases, & &1["expected"])),
      ["blocked"],
      "negative outcomes"
    )
    |> require_member("mix precommit", evidence["commands"] || [], "precommit command")
    |> require_member("mix assets.deploy", evidence["commands"] || [], "asset deploy command")
    |> require_member(
      "MIX_ENV=prod mix release --overwrite",
      evidence["commands"] || [],
      "release command"
    )
  end

  defp validate_lifecycle(errors, graph, evidence, root) do
    receipt = read(root, @receipt_path)

    expected_status =
      if String.contains?(receipt, "Status: **accepted-at-merged-candidate**"),
        do: "accepted_at_merged_candidate",
        else: "integration_candidate_merge_pending"

    errors
    |> require_equal(graph["status"], expected_status, "dependency graph lifecycle status")
    |> require_equal(
      evidence["status"],
      expected_status,
      "verification evidence lifecycle status"
    )
  end

  defp validate_sources(errors, root) do
    errors =
      Enum.reduce(@source_hashes, errors, fn {path, expected}, acc ->
        case File.read(Path.join(root, path)) do
          {:ok, body} -> require_equal(acc, sha256(body), expected, "pinned source #{path}")
          {:error, reason} -> ["pinned source #{path} unavailable: #{inspect(reason)}" | acc]
        end
      end)

    errors =
      case File.read(Path.join(root, "deps/shadcn_ui/priv/static/shadcn_ui.css")) do
        {:ok, body} ->
          require_equal(
            errors,
            sha256(body),
            "ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41",
            "ShadcnUI dependency stylesheet"
          )

        {:error, reason} ->
          ["ShadcnUI dependency stylesheet unavailable: #{inspect(reason)}" | errors]
      end

    mix = read(root, "mix.exs")
    lock = read(root, "mix.lock")
    app_js = read(root, "assets/js/app.js")
    app_css = read(root, "assets/css/app.css")
    vite = read(root, "assets/vite.config.mjs")
    policy = ContentSecurityPolicy.policy("HUIB2nonce")

    errors =
      errors
      |> require_contains(mix, ~s({:phoenix, "== 1.8.11"}), "Phoenix exact constraint")
      |> require_contains(mix, ~s({:phoenix_live_view, "== 1.2.9"}), "LiveView exact constraint")
      |> require_contains(mix, ~s({:dstar, "== 0.2.0"}), "Dstar exact constraint")
      |> require_contains(mix, ~s({:salad_ui, "== 1.0.0"}), "SaladUI exact constraint")
      |> require_contains(
        mix,
        "fe40eae63504adc4375aead4f0e741f158a4d86e",
        "ShadcnUI exact commit"
      )
      |> require_contains(
        lock,
        ~s("phoenix_pubsub": {:hex, :phoenix_pubsub, "2.2.0"),
        "PubSub retained lock"
      )
      |> require_contains(
        lock,
        ~s("spitfire": {:hex, :spitfire, "0.4.0"),
        "Spitfire retained lock"
      )
      |> require_contains(
        app_js,
        ~s(import "../vendor/datastar/datastar.js"),
        "Datastar local import"
      )
      |> require_contains(
        app_css,
        ~s(@import "../../deps/shadcn_ui/priv/static/shadcn_ui.css";),
        "ShadcnUI local import"
      )
      |> require_contains(vite, "sourcemap: false", "Vite source-map policy")
      |> require_contains(mix, "phx.digest.clean --all --no-compile", "clean digest input")
      |> require_contains(mix, "assets.normalize_digest_manifest", "normalized digest manifest")
      |> require_contains(
        policy,
        "require-trusted-types-for 'script'",
        "Trusted Types enforcement"
      )
      |> require_contains(policy, "trusted-types datastar", "Datastar Trusted Types policy")
      |> require_not_contains(policy, "unsafe-eval", "CSP unsafe-eval")
      |> require_not_contains(policy, "unsafe-inline", "CSP unsafe-inline")

    sources =
      [
        "lib/jido_code_web/**/*.ex",
        "lib/jido_code_web/**/*.heex",
        "assets/js/**/*.js",
        "assets/css/**/*.css",
        "assets/*.mjs"
      ]
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.uniq()
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(&{Path.relative_to(&1, root), File.read!(&1)})

    source_errors = check_product_sources(sources)
    Enum.reverse(source_errors) ++ errors
  end

  defp validate_documents(errors, root) do
    Enum.reduce(@required_documents, errors, fn path, acc ->
      if File.regular?(Path.join(root, path)),
        do: acc,
        else: ["missing HUI-B2 document: #{path}" | acc]
    end)
  end

  defp validate_closure_files(errors, root) do
    plan = read(root, @plan_path)
    receipt = read(root, @receipt_path)
    Enum.reverse(validate_closure(plan, receipt)) ++ errors
  end

  defp require_checkbox(errors, plan, id, label, checked?) do
    require_contains(
      errors,
      plan,
      "- [#{if(checked?, do: "x", else: " ")}] #{id} #{label}",
      "HUI-B2 #{id} closure checkbox"
    )
  end

  defp require_equal(errors, actual, expected, label) do
    if actual == expected,
      do: errors,
      else: ["#{label}; expected #{inspect(expected)}, got #{inspect(actual)}" | errors]
  end

  defp require_exact_set(errors, actual, expected, label) do
    if MapSet.new(actual) == MapSet.new(expected),
      do: errors,
      else: [
        "#{label}; expected #{inspect(Enum.sort(expected))}, got #{inspect(Enum.sort(actual))}"
        | errors
      ]
  end

  defp require_member(errors, value, values, label) do
    if value in values, do: errors, else: ["#{label} is missing" | errors]
  end

  defp require_present(errors, value, label) when is_binary(value) do
    if String.trim(value) == "", do: ["#{label} is empty" | errors], else: errors
  end

  defp require_present(errors, value, label) do
    if is_nil(value), do: ["#{label} is missing" | errors], else: errors
  end

  defp require_contains(errors, body, expected, label) do
    if is_binary(body) and String.contains?(body, expected),
      do: errors,
      else: ["#{label} is missing" | errors]
  end

  defp require_not_contains(errors, body, forbidden, label) do
    if String.contains?(body, forbidden),
      do: ["#{label} is present" | errors],
      else: errors
  end

  defp require_match(errors, body, pattern, label) do
    if Regex.match?(pattern, body),
      do: errors,
      else: ["#{label} does not match" | errors]
  end

  defp read(root, path) do
    case File.read(Path.join(root, path)) do
      {:ok, body} -> body
      {:error, reason} -> "missing #{path}: #{inspect(reason)}"
    end
  end

  defp sha256(body), do: body |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)
end
