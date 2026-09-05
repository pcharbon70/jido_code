defmodule JidoCode.Architecture.HypermediaUIPhaseC1 do
  @moduledoc false

  alias JidoCode.Architecture.HypermediaUISuccessorEvidence

  @manifest_path "priv/architecture/hypermedia_ui/phase_c1_implementation_evidence.json"
  @baseline "797e308bc16b609eb6273d07ae96ee47a4cc3512"
  @predecessor "63d2689321121775a46bf531d004ac4de44b81f2"
  @sections ~w[1.1 1.2 1.3 1.4]
  @invariants ~w[
    named_human_subjects_are_distinct_from_operator_service_and_agent_principals
    browser_fields_never_supply_identity_scope_grants_assurance_or_revisions
    roles_explain_navigation_but_never_union_exact_grants
    session_and_account_generations_revoke_future_access
    unavailable_authenticator_recovery_and_step_up_postures_fail_closed
    credentials_tokens_and_protected_content_are_absent_from_events_and_telemetry
    predecessor_dependency_asset_and_facade_pins_remain_unchanged
  ]

  @spec check(Path.t()) :: {:ok, []} | {:error, [String.t()]}
  def check(root \\ File.cwd!()) do
    with {:ok, evidence} <- load(root) do
      case validate(evidence, root) do
        [] -> {:ok, []}
        errors -> {:error, errors}
      end
    end
  end

  @spec load(Path.t()) :: {:ok, map()} | {:error, [String.t()]}
  def load(root \\ File.cwd!()) do
    path = Path.join(root, @manifest_path)

    with {:ok, body} <- File.read(path),
         {:ok, evidence} <- Jason.decode(body) do
      {:ok, evidence}
    else
      {:error, %Jason.DecodeError{} = reason} ->
        {:error, ["#{path}: invalid JSON: #{Exception.message(reason)}"]}

      {:error, reason} ->
        {:error, ["#{path}: unavailable evidence: #{inspect(reason)}"]}
    end
  end

  @spec validate(map(), Path.t()) :: [String.t()]
  def validate(evidence, root) when is_map(evidence) do
    completed = evidence["completed_sections"] || []
    sources = evidence["source_digests"] || %{}
    identity = evidence["identity_authority"] || %{}

    []
    |> require_equal(evidence["schema_version"], 1, "schema version")
    |> require_equal(evidence["phase"], "HUI-C1", "phase")
    |> require_member(
      evidence["status"],
      [
        "implementation_in_progress",
        "integration_candidate_merge_pending",
        "accepted_at_merged_candidate"
      ],
      "lifecycle status"
    )
    |> require_equal(evidence["baseline_commit"], @baseline, "authorized baseline")
    |> require_equal(evidence["predecessor_candidate"], @predecessor, "HUI-B4 candidate")
    |> require_equal(ordered_prefix?(completed), true, "completed section order")
    |> require_exact_set(evidence["invariants"] || [], @invariants, "phase invariants")
    |> require_equal(identity["store_owner"], "JidoCode.Identity.Store", "identity owner")
    |> require_equal(identity["file_role"], "identity_authority", "identity file role")
    |> require_equal(identity["snapshot_integrity"], "HMAC-SHA-256", "snapshot integrity")
    |> require_equal(identity["credential_verifier"], "PBKDF2-HMAC-SHA-256", "verifier")
    |> require_equal(
      identity["browser_operator_compatibility"],
      "prohibited",
      "operator browser posture"
    )
    |> require_equal(
      identity["phishing_resistant"],
      "unavailable_until_configured",
      "phishing-resistant posture"
    )
    |> require_equal(identity["recovery"], "unavailable_until_configured", "recovery posture")
    |> validate_source_paths(sources, root)
    |> Enum.reverse()
  end

  def validate(_evidence, _root), do: ["HUI-C1 evidence must be a map"]

  defp ordered_prefix?(sections), do: sections == Enum.take(@sections, length(sections))

  defp validate_source_paths(errors, sources, root) when map_size(sources) > 0 do
    Enum.reduce(sources, errors, fn {path, expected}, acc ->
      cond do
        not HypermediaUISuccessorEvidence.mutable_path?(path) and
          not String.starts_with?(path, "lib/jido_code/identity") and
            path != "lib/mix/tasks/identity.bootstrap.ex" ->
          ["unauthorized HUI-C1 source path #{path}" | acc]

        not Regex.match?(~r/^[a-f0-9]{64}$/, expected) ->
          ["invalid source digest for #{path}" | acc]

        true ->
          case File.read(Path.join(root, path)) do
            {:ok, body} -> require_equal(acc, sha256(body), expected, "source digest #{path}")
            {:error, reason} -> ["#{path}: unavailable source: #{inspect(reason)}" | acc]
          end
      end
    end)
  end

  defp validate_source_paths(errors, _sources, _root), do: ["source digests are empty" | errors]

  defp require_equal(errors, actual, expected, _label) when actual == expected, do: errors

  defp require_equal(errors, actual, expected, label),
    do: ["#{label}: expected #{inspect(expected)}, got #{inspect(actual)}" | errors]

  defp require_member(errors, value, values, label) do
    if value in values, do: errors, else: ["#{label}: unexpected #{inspect(value)}" | errors]
  end

  defp require_exact_set(errors, actual, expected, label) do
    if MapSet.new(actual) == MapSet.new(expected),
      do: errors,
      else: ["#{label} is not exact" | errors]
  end

  defp sha256(body), do: :crypto.hash(:sha256, body) |> Base.encode16(case: :lower)
end
