defmodule JidoCode.Architecture.HypermediaUISuccessorEvidence do
  @moduledoc false

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
    with true <- MapSet.member?(@phase_c1_mutable_paths, path),
         {:ok, body} <- File.read(Path.join(root, @phase_c1_manifest)),
         {:ok, evidence} <- Jason.decode(body),
         "HUI-C1" <- evidence["phase"],
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

  @spec mutable_path?(String.t()) :: boolean()
  def mutable_path?(path), do: MapSet.member?(@phase_c1_mutable_paths, path)
end
