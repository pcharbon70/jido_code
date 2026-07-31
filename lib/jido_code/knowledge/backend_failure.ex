defmodule JidoCode.Knowledge.BackendFailure do
  @moduledoc false

  alias JidoCode.Knowledge.Error

  @spec translate(term(), atom()) :: Error.t()
  def translate(reason, operation) when is_atom(operation) do
    Error.from_backend(classify(reason, operation), operation, reason)
  end

  @spec classify(term(), atom()) :: Error.kind()
  def classify(reason, operation) do
    fingerprint = reason |> inspect(limit: 20, printable_limit: 500) |> String.downcase()

    cond do
      reason in [:timeout, :open_timeout] or String.contains?(fingerprint, "timeout") ->
        :timeout

      reason in [:schema_mismatch, :missing_schema_metadata] or
          String.contains?(fingerprint, ["schema mismatch", "column families mismatch"]) ->
        :incompatible

      String.contains?(fingerprint, ["lock hold", "lock:", "resource temporarily unavailable"]) ->
        :locked

      String.contains?(fingerprint, ["corrupt", "checksum", "invalid argument: manifest"]) ->
        :corrupt

      String.contains?(fingerprint, ["eacces", "permission denied", "read-only file system"]) ->
        :persistence_failure

      operation in [:atomic_commit, :backup_store, :restore_store, :export_store] ->
        :persistence_failure

      true ->
        :unavailable
    end
  end
end
