defmodule JidoCode.Architecture.HypermediaUISuccessorEvidence do
  @moduledoc false

  @phase_c2_manifest "priv/architecture/hypermedia_ui/phase_c2_implementation_evidence.json"
  @phase_c2_mutable_paths MapSet.new(~w[
    assets/css/app.css
    assets/js/theme.js
    lib/jido_code_web/components/layouts.ex
    lib/jido_code_web/components/layouts/root.html.heex
    lib/jido_code_web/components/ui.ex
    lib/jido_code_web/controllers/qualification/hypermedia_controller.ex
    lib/jido_code_web/controllers/qualification/hypermedia_html/index.html.heex
  ])

  @phase_c1_manifest "priv/architecture/hypermedia_ui/phase_c1_implementation_evidence.json"
  @phase_c1_mutable_paths MapSet.new(~w[
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
  ])

  @spec digest(Path.t(), String.t()) :: String.t() | nil
  def digest(root, path) do
    phase_digest(root, path, @phase_c2_manifest, @phase_c2_mutable_paths, "HUI-C2") ||
      phase_digest(root, path, @phase_c1_manifest, @phase_c1_mutable_paths, "HUI-C1")
  end

  @spec mutable_path?(String.t()) :: boolean()
  def mutable_path?(path), do: phase_c2_mutable_path?(path) or phase_c1_mutable_path?(path)

  @spec phase_c1_mutable_path?(String.t()) :: boolean()
  def phase_c1_mutable_path?(path), do: MapSet.member?(@phase_c1_mutable_paths, path)

  @spec phase_c2_mutable_path?(String.t()) :: boolean()
  def phase_c2_mutable_path?(path), do: MapSet.member?(@phase_c2_mutable_paths, path)

  defp phase_digest(root, path, manifest_path, mutable_paths, expected_phase) do
    with true <- MapSet.member?(mutable_paths, path),
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
