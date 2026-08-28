defmodule JidoCode.Factory.ManagedCoding.Context do
  @moduledoc "Exact managed coding context manifest with material-staleness detection."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Factory.RepositoryWiki.ContextAssembler
  alias JidoCode.Knowledge

  @resource_pins ~w[task_iri snapshot_iri lease_iri capability_iri]a
  @digest_pins ~w[
    source_revision workspace_revision policy_revision prompt_revision tool_revision
    profile_revision authority_revision
  ]a
  @wiki_digest_pins ~w[wiki_edition_root wiki_context_profile_digest wiki_compiler_digest]a
  @enforce_keys [
    :compiled,
    :digest,
    :fingerprint,
    :pins,
    :memory_mode,
    :repository_wiki_mode
  ]
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
         {:ok, repository_wiki, wiki_mode} <-
           repository_wiki(attributes[:repository_wiki], pins, compiler),
         {:ok, compiled} <-
           ContextAssembler.compile(compiler, memory, repository_wiki, options) do
      fingerprint = fingerprint(pins)
      digest = WorkspaceDigest.digest({compiled.digest, fingerprint, mode, wiki_mode})

      {:ok,
       %__MODULE__{
         compiled: compiled,
         digest: digest,
         fingerprint: fingerprint,
         pins: canonical(pins),
         memory_mode: mode,
         repository_wiki_mode: wiki_mode
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
         :ok <- optional_digest(pins[:memory_partition_digest]),
         :ok <- optional_wiki_pins(pins) do
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

  defp repository_wiki(value, _pins, _compiler) when value in [:disabled, nil],
    do: {:ok, :disabled, :disabled}

  defp repository_wiki(repository_wiki, pins, compiler) when is_map(repository_wiki) do
    with true <- repository_wiki[:authorized?] == true,
         true <- repository_wiki[:current?] == true,
         true <- repository_wiki[:source_complete?] == true,
         true <- repository_wiki[:enrollment_visible?] == true,
         true <- repository_wiki[:preview?] == false,
         packet when is_map(packet) <- repository_wiki[:packet],
         true <- Knowledge.repository_wiki_context_packet?(packet),
         true <- packet.task_iri == pins[:task_iri],
         true <- packet.session_iri == pins[:wiki_session_iri],
         true <- packet.source_snapshot_iri == pins[:snapshot_iri],
         true <- packet.source_revision == pins[:source_revision],
         true <- packet.edition_root == pins[:wiki_edition_root],
         true <- packet.profile_digest == pins[:wiki_context_profile_digest],
         true <- packet.compiler_digest == pins[:wiki_compiler_digest],
         true <- packet.attempt_iri == compiler[:attempt_iri],
         true <- packet.repository_iri == compiler[:repository_iri] do
      {:ok, packet, :authorized_advisory}
    else
      _invalid -> invalid(:managed_coding_repository_wiki_context)
    end
  end

  defp repository_wiki(_repository_wiki, _pins, _compiler),
    do: invalid(:managed_coding_repository_wiki_context)

  defp canonical(pins) do
    pins
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Map.new()
  end

  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp optional_digest(nil), do: :ok
  defp optional_digest(value), do: if(digest?(value), do: :ok, else: :error)

  defp optional_wiki_pins(pins) do
    values = Enum.map(@wiki_digest_pins, &pins[&1])

    cond do
      Enum.all?(values, &is_nil/1) and is_nil(pins[:wiki_session_iri]) ->
        :ok

      Enum.all?(values, &digest?/1) and Identity.validate_resource(pins[:wiki_session_iri]) == :ok ->
        :ok

      true ->
        :error
    end
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
