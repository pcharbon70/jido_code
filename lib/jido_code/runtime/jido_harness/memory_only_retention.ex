defmodule JidoCode.Runtime.JidoHarness.MemoryOnlyRetention do
  @moduledoc """
  Builds a controller-owned retention root that makes the pinned upstream disk
  journal fail closed while leaving its bounded in-memory tail available.

  JidoHarness treats journal-open failure as an explicit memory-only fallback.
  A regular file is supplied as `journal_dir`, so no process, run, or nested
  session can create a JSONL directory below it.
  """

  alias JidoCode.Factory.AdapterError

  @architecture_file_role :temporary

  @enforce_keys [:root, :journal_barrier, :retention]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          root: String.t(),
          journal_barrier: String.t(),
          retention: map()
        }

  @doc false
  def architecture_file_role, do: @architecture_file_role

  @spec prepare(String.t(), String.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def prepare(base_dir, runtime_key, journal)
      when is_binary(base_dir) and is_binary(runtime_key) and is_map(journal) do
    with true <- Path.type(base_dir) == :absolute,
         true <- Regex.match?(~r/^[a-f0-9]{64}$/, runtime_key),
         {:ok, memory_bytes} <- memory_bytes(journal),
         root = Path.join(base_dir, "jido-code-harness-" <> runtime_key),
         barrier = Path.join(root, "memory-only-journal-barrier"),
         :ok <- File.mkdir(root),
         :ok <- File.chmod(root, 0o700),
         :ok <- File.write(barrier, "memory-only\n", [:binary, :exclusive]),
         :ok <- File.chmod(barrier, 0o600) do
      {:ok,
       %__MODULE__{
         root: root,
         journal_barrier: barrier,
         retention: %{journal_dir: barrier, memory_bytes: memory_bytes}
       }}
    else
      _invalid -> invalid(:jido_harness_memory_retention)
    end
  rescue
    _error -> invalid(:jido_harness_memory_retention)
  end

  def prepare(_base_dir, _runtime_key, _journal),
    do: invalid(:jido_harness_memory_retention)

  @spec cleanup(t()) :: :ok | {:error, AdapterError.t()}
  def cleanup(%__MODULE__{root: root, journal_barrier: barrier}) do
    with true <- Path.dirname(barrier) == root,
         true <- Path.basename(root) |> String.starts_with?("jido-code-harness-"),
         {:ok, _removed} <- File.rm_rf(root) do
      :ok
    else
      _invalid -> invalid(:jido_harness_memory_retention_cleanup)
    end
  rescue
    _error -> invalid(:jido_harness_memory_retention_cleanup)
  end

  def cleanup(_retention), do: invalid(:jido_harness_memory_retention_cleanup)

  defp memory_bytes(%{mode: :memory_only, memory_bytes: bytes})
       when bytes in 1..1_048_576,
       do: {:ok, bytes}

  defp memory_bytes(_journal), do: :error

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
