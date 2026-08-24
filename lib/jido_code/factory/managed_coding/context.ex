defmodule JidoCode.Factory.ManagedCoding.Context do
  @moduledoc "Exact managed coding context manifest with material-staleness detection."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Harness.ContextCompiler
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest

  @resource_pins ~w[task_iri snapshot_iri lease_iri capability_iri]a
  @digest_pins ~w[
    source_revision workspace_revision policy_revision prompt_revision tool_revision
    profile_revision authority_revision
  ]a
  @enforce_keys [:compiled, :digest, :fingerprint, :pins, :memory_mode]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec compile(map(), keyword()) :: {:ok, t()} | {:error, AdapterError.t()}
  def compile(attributes, options \\ [])

  def compile(attributes, options) when is_map(attributes) and is_list(options) do
    with compiler when is_map(compiler) <- attributes[:compiler],
         pins when is_map(pins) <- attributes[:pins],
         :ok <- validate_pins(pins),
         true <- compiler[:snapshot_iri] == pins[:snapshot_iri],
         true <- compiler[:source_graph_revisions] == pins[:graph_revisions],
         {:ok, memory, mode} <- memory(attributes[:memory], pins),
         {:ok, compiled} <- ContextCompiler.compile_with_memory(compiler, memory, options) do
      fingerprint = fingerprint(pins)
      digest = WorkspaceDigest.digest({compiled.digest, fingerprint, mode})

      {:ok,
       %__MODULE__{
         compiled: compiled,
         digest: digest,
         fingerprint: fingerprint,
         pins: canonical(pins),
         memory_mode: mode
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      {:error, _knowledge_error} -> invalid(:managed_coding_context_compile)
      _invalid -> invalid(:managed_coding_context_compile)
    end
  rescue
    _error -> invalid(:managed_coding_context_compile)
  end

  def compile(_attributes, _options), do: invalid(:managed_coding_context_compile)

  @spec recompile?(t(), map()) :: boolean()
  def recompile?(%__MODULE__{} = context, current_pins) when is_map(current_pins) do
    validate_pins(current_pins) != :ok or fingerprint(current_pins) != context.fingerprint
  end

  def recompile?(%__MODULE__{}, _current_pins), do: true

  @spec fingerprint(map()) :: String.t()
  def fingerprint(pins), do: pins |> canonical() |> WorkspaceDigest.digest()

  defp validate_pins(pins) do
    with true <- Enum.all?(@resource_pins, &(Identity.validate_resource(pins[&1]) == :ok)),
         true <- Enum.all?(@digest_pins, &digest?(pins[&1])),
         revisions when is_map(revisions) and map_size(revisions) in 1..32 <-
           pins[:graph_revisions],
         true <-
           Enum.all?(revisions, fn {graph, revision} ->
             is_binary(graph) and is_integer(revision) and revision >= 0
           end),
         generation when is_integer(generation) and generation >= 0 <- pins[:erasure_generation],
         :ok <- optional_digest(pins[:memory_partition_digest]) do
      :ok
    else
      _invalid -> invalid(:managed_coding_context_pins)
    end
  end

  defp memory(value, _pins) when value in [:disabled, nil], do: {:ok, :disabled, :disabled}

  defp memory(memory, pins) when is_map(memory) do
    with true <- memory[:authorized?] == true,
         true <- memory[:temporally_eligible?] == true,
         true <- memory[:source_complete?] == true,
         %DateTime{} = expires_at <- memory[:expires_at],
         true <- DateTime.compare(expires_at, DateTime.utc_now()) == :gt,
         true <- memory[:partition_digest] == pins[:memory_partition_digest],
         true <- memory[:erasure_generation] == pins[:erasure_generation],
         packet when is_map(packet) <- memory[:packet] do
      {:ok, packet, :authorized_evidence}
    else
      _invalid -> invalid(:managed_coding_memory_context)
    end
  end

  defp memory(_memory, _pins), do: invalid(:managed_coding_memory_context)

  defp canonical(pins) do
    pins
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Map.new()
  end

  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp optional_digest(nil), do: :ok
  defp optional_digest(value), do: if(digest?(value), do: :ok, else: :error)
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
