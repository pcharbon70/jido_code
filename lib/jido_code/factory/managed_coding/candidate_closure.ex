defmodule JidoCode.Factory.ManagedCoding.CandidateClosure do
  @moduledoc "Validates and atomically closes content-addressed managed coding candidates."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CandidateClosureResult
  alias JidoCode.Factory.ManagedCoding.CandidateManifest

  @spec close(module(), term(), map(), map()) ::
          {:ok, CandidateClosureResult.t()} | {:error, AdapterError.t()}
  def close(store_module, store, capture, policy)
      when is_atom(store_module) and is_map(capture) and is_map(policy) do
    with :ok <- capture_status(capture),
         :ok <- non_empty(capture),
         :ok <- complete(capture),
         :ok <- changed_file_limit(capture, policy),
         :ok <- diff_limit(capture, policy),
         :ok <- path_scope(capture, policy),
         :ok <- file_modes(capture),
         :ok <- binary_policy(capture, policy),
         :ok <- content_policy(capture),
         :ok <- exact_manifest(capture),
         {:ok, manifest} <- CandidateManifest.new(capture),
         {:ok, store_outcome} <- store_module.create(store, manifest),
         true <- store_outcome in [:committed, :idempotent] do
      result(:ready, :none, manifest, capture[:closure_evidence_iris] || [])
    else
      {:classification, status, reason} ->
        result(status, reason, nil, capture[:closure_evidence_iris] || [])

      {:error, %AdapterError{kind: :conflict}} ->
        result(
          :conflicting,
          :immutable_store_conflict,
          nil,
          capture[:closure_evidence_iris] || []
        )

      {:error, %AdapterError{} = error} ->
        {:error, error}

      _invalid ->
        result(:capture_failed, :capture_unavailable, nil, capture[:closure_evidence_iris] || [])
    end
  rescue
    _error -> result(:capture_failed, :capture_unavailable, nil, [])
  end

  def close(_store_module, _store, _capture, _policy),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_candidate_closure)}

  defp capture_status(%{capture_status: :complete}), do: :ok
  defp capture_status(%{capture_status: :partial}), do: classify(:partial, :incomplete_capture)

  defp capture_status(%{capture_status: :conflicting}),
    do: classify(:conflicting, :conflicting_capture)

  defp capture_status(_capture), do: classify(:capture_failed, :capture_unavailable)

  defp non_empty(%{changed_files: []}), do: classify(:empty, :no_changes)
  defp non_empty(_capture), do: :ok

  defp complete(%{omissions: []}), do: :ok
  defp complete(_capture), do: classify(:partial, :incomplete_capture)

  defp changed_file_limit(capture, %{max_changed_files: maximum})
       when is_integer(maximum) and maximum > 0 do
    if length(capture[:changed_files] || []) <= maximum,
      do: :ok,
      else: classify(:oversized, :changed_file_limit)
  end

  defp changed_file_limit(_capture, _policy), do: classify(:policy_blocked, :changed_file_limit)

  defp diff_limit(%{diff_bytes: bytes}, %{max_diff_bytes: maximum})
       when is_integer(bytes) and bytes >= 0 and is_integer(maximum) and maximum > 0 do
    if bytes <= maximum, do: :ok, else: classify(:oversized, :diff_byte_limit)
  end

  defp diff_limit(_capture, _policy), do: classify(:capture_failed, :capture_unavailable)

  defp path_scope(capture, %{allowed_paths: allowed}) when is_list(allowed) and allowed != [] do
    if Enum.all?(capture.changed_files, fn file ->
         Enum.any?(allowed, fn prefix ->
           file.path == prefix or String.starts_with?(file.path, prefix <> "/")
         end)
       end),
       do: :ok,
       else: classify(:policy_blocked, :path_scope)
  end

  defp path_scope(_capture, _policy), do: classify(:policy_blocked, :path_scope)

  defp file_modes(capture) do
    if Enum.all?(capture.changed_files, &(&1.mode in [0o644, 0o755, :deleted])),
      do: :ok,
      else: classify(:policy_blocked, :file_mode)
  end

  defp binary_policy(capture, %{allow_binary?: allow_binary?}) when is_boolean(allow_binary?) do
    if allow_binary? or Enum.all?(capture.changed_files, &(not &1.binary?)),
      do: :ok,
      else: classify(:policy_blocked, :binary_policy)
  end

  defp binary_policy(_capture, _policy), do: classify(:policy_blocked, :binary_policy)

  defp content_policy(%{forbidden_content_scan: :clean, secret_scan: :clean}), do: :ok

  defp content_policy(%{forbidden_content_scan: status}) when status != :clean,
    do: classify(:policy_blocked, :forbidden_content)

  defp content_policy(_capture), do: classify(:policy_blocked, :secret_scan)

  defp exact_manifest(capture) do
    paths = capture.changed_files |> Enum.map(& &1.path) |> Enum.sort()
    untracked = capture[:untracked_paths] |> List.wrap() |> Enum.sort()
    manifest_paths = capture[:manifest_paths] |> List.wrap() |> Enum.sort()

    if paths == manifest_paths and Enum.all?(untracked, &(&1 in paths)),
      do: :ok,
      else: classify(:policy_blocked, :untracked_material)
  end

  defp result(status, reason, manifest, evidence) do
    CandidateClosureResult.new(%{
      status: status,
      reason: reason,
      manifest: manifest,
      evidence_iris: evidence
    })
  end

  defp classify(status, reason), do: {:classification, status, reason}
end
