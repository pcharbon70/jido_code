defmodule JidoCode.Architecture.HypermediaUISuccessorEvidence do
  @moduledoc false

  @phase_d2_manifest "priv/architecture/hypermedia_ui/phase_d2_implementation_evidence.json"
  @phase_d2_mutable_paths ~w[
    assets/js/app.js
    assets/js/read_projection.js
    lib/jido_code/application.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c3.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c4.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c5.ex
    lib/jido_code/architecture/hypermedia_ui_phase_d1.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/jido_code_web/components/product_page.ex
    lib/jido_code_web/plugs/read_body.ex
    lib/jido_code_web/product_controller.ex
    lib/jido_code_web/product_request.ex
    lib/jido_code_web/read_enhancement.ex
    lib/jido_code_web/read_response.ex
    lib/jido_code_web/read_signals.ex
    lib/jido_code_web/router.ex
    lib/mix/tasks/architecture.check.ex
    test/jido_code/architecture/hypermedia_ui_phase_a1_test.exs
  ]

  @phase_d1_manifest "priv/architecture/hypermedia_ui/phase_d1_implementation_evidence.json"
  @phase_d1_mutable_paths ~w[
    assets/js/app.js
    assets/vite.config.mjs
    lib/jido_code/application.ex
    lib/jido_code/architecture/hypermedia_ui_phase_b2.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c3.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c4.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c5.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/jido_code_web/components/product_page.ex
    lib/jido_code_web/controllers/account_controller.ex
    lib/jido_code_web/controllers/account_html/sessions.html.heex
    lib/jido_code_web/endpoint.ex
    lib/jido_code_web/product_controller.ex
    lib/jido_code_web/product_request.ex
    lib/jido_code_web/read_enhancement.ex
    lib/jido_code_web/router.ex
    lib/mix/tasks/architecture.check.ex
    test/jido_code/architecture/hypermedia_ui_phase_a1_test.exs
  ]

  @phase_c5_manifest "priv/architecture/hypermedia_ui/phase_c5_implementation_evidence.json"
  @phase_c5_mutable_paths ~w[
    lib/jido_code/architecture/hypermedia_ui_phase_c4.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/mix/tasks/architecture.check.ex
  ]

  @phase_c4_manifest "priv/architecture/hypermedia_ui/phase_c4_implementation_evidence.json"
  @phase_c4_mutable_paths ~w[
    lib/jido_code/application.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c3.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/jido_code_web/controllers/account_controller.ex
    lib/jido_code_web/controllers/attempt_html.ex
    lib/jido_code_web/controllers/attempt_html/show.html.heex
    lib/jido_code_web/controllers/factory_controller.ex
    lib/jido_code_web/controllers/factory_html.ex
    lib/jido_code_web/controllers/factory_html/attention.html.heex
    lib/jido_code_web/controllers/factory_html/fleet.html.heex
    lib/jido_code_web/controllers/project_controller.ex
    lib/jido_code_web/controllers/project_html.ex
    lib/jido_code_web/controllers/project_html/attempts.html.heex
    lib/jido_code_web/controllers/project_html/dependencies.html.heex
    lib/jido_code_web/controllers/project_html/index.html.heex
    lib/jido_code_web/controllers/project_html/overview.html.heex
    lib/jido_code_web/controllers/project_html/wiki.html.heex
    lib/jido_code_web/product_controller.ex
    lib/jido_code_web/product_page_view_model.ex
    lib/jido_code_web/product_request.ex
    lib/mix/tasks/architecture.check.ex
    test/jido_code/architecture/hypermedia_ui_phase_a1_test.exs
  ]

  @phase_c3_manifest "priv/architecture/hypermedia_ui/phase_c3_implementation_evidence.json"
  @phase_c3_mutable_paths ~w[
    config/config.exs
    config/test.exs
    lib/jido_code/architecture/hypermedia_ui_phase_c1.ex
    lib/jido_code/architecture/hypermedia_ui_phase_c2.ex
    lib/jido_code/architecture/hypermedia_ui_successor_evidence.ex
    lib/jido_code/identity/sessions.ex
    lib/jido_code/identity/store.ex
    lib/jido_code_web/components/layouts/root.html.heex
    lib/jido_code_web/controllers/auth_controller.ex
    lib/jido_code_web/controllers/auth_html/new.html.heex
    lib/jido_code_web/endpoint.ex
    lib/jido_code_web/product_auth.ex
    lib/jido_code_web/router.ex
    lib/mix/tasks/architecture.check.ex
  ]

  @phase_c2_manifest "priv/architecture/hypermedia_ui/phase_c2_implementation_evidence.json"
  @phase_c2_mutable_paths ~w[
    assets/css/app.css
    assets/js/app.js
    assets/js/theme.js
    lib/jido_code_web/components/layouts.ex
    lib/jido_code_web/components/layouts/root.html.heex
    lib/jido_code_web/components/ui.ex
    lib/jido_code_web/controllers/qualification/hypermedia_controller.ex
    lib/jido_code_web/controllers/qualification/hypermedia_html/index.html.heex
  ]

  @phase_c1_manifest "priv/architecture/hypermedia_ui/phase_c1_implementation_evidence.json"
  @phase_c1_mutable_paths ~w[
    config/config.exs
    config/runtime.exs
    config/test.exs
    lib/jido_code/application.ex
    lib/jido_code/architecture/hypermedia_ui_phase_a4.ex
    lib/jido_code/architecture/hypermedia_ui_phase_b2.ex
    lib/jido_code_web/endpoint.ex
    lib/jido_code_web/router.ex
    lib/jido_code_web/product_auth.ex
    lib/jido_code_web/plugs/require_same_origin.ex
    lib/jido_code_web/plugs/require_product_area.ex
    lib/jido_code_web/controllers/auth_controller.ex
    lib/jido_code_web/controllers/auth_html/new.html.heex
  ]

  @spec digest(Path.t(), String.t()) :: String.t() | nil
  def digest(root, path) do
    phase_digest(root, path, @phase_d2_manifest, @phase_d2_mutable_paths, "HUI-D2") ||
      phase_digest(root, path, @phase_d1_manifest, @phase_d1_mutable_paths, "HUI-D1") ||
      phase_digest(root, path, @phase_c5_manifest, @phase_c5_mutable_paths, "HUI-C5") ||
      phase_digest(root, path, @phase_c4_manifest, @phase_c4_mutable_paths, "HUI-C4") ||
      phase_digest(root, path, @phase_c3_manifest, @phase_c3_mutable_paths, "HUI-C3") ||
      phase_digest(root, path, @phase_c2_manifest, @phase_c2_mutable_paths, "HUI-C2") ||
      phase_digest(root, path, @phase_c1_manifest, @phase_c1_mutable_paths, "HUI-C1")
  end

  @spec mutable_path?(String.t()) :: boolean()
  def mutable_path?(path),
    do:
      phase_d2_mutable_path?(path) or phase_d1_mutable_path?(path) or phase_c5_mutable_path?(path) or
        phase_c4_mutable_path?(path) or
        phase_c3_mutable_path?(path) or
        phase_c2_mutable_path?(path) or phase_c1_mutable_path?(path)

  @spec phase_c5_mutable_path?(String.t()) :: boolean()
  def phase_c5_mutable_path?(path), do: path in @phase_c5_mutable_paths

  @spec phase_d1_mutable_path?(String.t()) :: boolean()
  def phase_d1_mutable_path?(path), do: path in @phase_d1_mutable_paths

  @spec phase_d2_mutable_path?(String.t()) :: boolean()
  def phase_d2_mutable_path?(path), do: path in @phase_d2_mutable_paths

  def d2_predecessor_digest(root, path) do
    with true <- path in @phase_d2_mutable_paths,
         {:ok, body} <- File.read(Path.join(root, @phase_d2_manifest)),
         {:ok, %{"phase" => "HUI-D2"} = evidence} <- Jason.decode(body) do
      get_in(evidence, ["predecessor_source_digests", path])
    else
      _ -> nil
    end
  end

  @spec phase_c4_mutable_path?(String.t()) :: boolean()
  def phase_c4_mutable_path?(path), do: path in @phase_c4_mutable_paths

  @spec phase_c3_mutable_path?(String.t()) :: boolean()
  def phase_c3_mutable_path?(path), do: path in @phase_c3_mutable_paths

  @spec phase_c1_mutable_path?(String.t()) :: boolean()
  def phase_c1_mutable_path?(path), do: path in @phase_c1_mutable_paths

  @spec phase_c2_mutable_path?(String.t()) :: boolean()
  def phase_c2_mutable_path?(path), do: path in @phase_c2_mutable_paths

  defp phase_digest(root, path, manifest_path, mutable_paths, expected_phase) do
    with true <- path in mutable_paths,
         {:ok, body} <- File.read(Path.join(root, manifest_path)),
         {:ok, evidence} <- Jason.decode(body),
         ^expected_phase <- evidence["phase"],
         status
         when status in [
                "implementation_in_progress",
                "integration_candidate_merge_pending",
                "accepted_at_merged_candidate"
              ] <- evidence["status"],
         digest when is_binary(digest) <- get_in(evidence, ["source_digests", path]),
         true <- Regex.match?(~r/^[a-f0-9]{64}$/, digest) do
      digest
    else
      _unavailable -> nil
    end
  end
end
