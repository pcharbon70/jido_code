defmodule JidoCode.Runtime.JidoHarness.CodexReadiness do
  @moduledoc "Exact expiring prompt-free readiness for the DGA1 developer-local Codex tuple."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Runtime.JidoHarness.CodexLocalReadinessProbe
  alias JidoCode.Runtime.JidoHarness.CodexLocalRelease
  alias JidoCode.Runtime.JidoHarness.CodexReadinessProbe
  alias JidoCode.Runtime.JidoHarness.CodexRelease
  alias JidoCode.Runtime.JidoHarness.ExecutableRegistry

  @component_fields ~w[worker sandbox network candidate_capture check_registry verifier]a
  @maximum_ttl_seconds 900

  @spec discover(map(), keyword()) :: {:ok, map()} | {:error, AdapterError.t()}
  def discover(attributes, options \\ [])

  def discover(attributes, options) when is_map(attributes) and is_list(options) do
    at = Keyword.get(options, :at, DateTime.utc_now())
    ttl = Keyword.get(options, :ttl_seconds, 300)
    probe = Keyword.get(options, :probe, CodexLocalReadinessProbe)
    probe_options = Keyword.get(options, :probe_options, [])
    executable_registry = Keyword.get(options, :executable_registry, ExecutableRegistry)

    with %DateTime{} <- at,
         true <- is_integer(ttl) and ttl in 1..@maximum_ttl_seconds,
         :ok <- credential_reference(attributes),
         generation when is_integer(generation) and generation > 0 <-
           attributes[:credential_generation],
         :ok <- infrastructure(attributes[:infrastructure]),
         true <- probe?(probe),
         true <- executable_registry?(executable_registry),
         {:ok, executable} <- executable_registry.resolve("codex_cli"),
         true <- executable[:sha256] == CodexRelease.executable_sha256(),
         true <- executable[:version] == CodexRelease.cli_version(),
         {:ok, login} <- probe.login_status(executable, probe_options),
         true <- login in [:authenticated, :unauthenticated, :unknown] do
      receipt = %{
        profile: :codex_dga1,
        profile_digest: CodexLocalRelease.manifest().profile_digest,
        adapter_release_digest: CodexLocalRelease.manifest().adapter_release_digest,
        local_release_digest: CodexLocalRelease.digest(),
        executable_digest: executable.sha256,
        cli_version: executable.version,
        credential_reference_iri: attributes.credential_reference_iri,
        credential_generation: generation,
        login: %{
          state: login,
          actor_identity: :not_claimed,
          provider_identity: :not_retained
        },
        infrastructure: attributes.infrastructure,
        revisions: CodexLocalRelease.revisions(),
        discovery: :non_billable,
        provider_request: false,
        prompt_sent: false,
        ready: login == :authenticated and ready?(attributes.infrastructure),
        observed_at: DateTime.truncate(at, :microsecond),
        expires_at: at |> DateTime.add(ttl, :second) |> DateTime.truncate(:microsecond)
      }

      {:ok, Map.put(receipt, :observation_digest, digest(receipt))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      {:error, _reason} -> unavailable(:codex_local_readiness)
      _invalid -> invalid(:codex_local_readiness)
    end
  rescue
    _error -> unavailable(:codex_local_readiness)
  end

  def discover(_attributes, _options), do: invalid(:codex_local_readiness)

  @spec current?(map(), map(), DateTime.t()) :: boolean()
  def current?(receipt, current, %DateTime{} = at) when is_map(receipt) and is_map(current) do
    expected = Map.drop(receipt, [:observation_digest])

    receipt[:observation_digest] == digest(expected) and receipt[:ready] == true and
      DateTime.compare(receipt.observed_at, at) in [:lt, :eq] and
      DateTime.compare(at, receipt.expires_at) == :lt and
      Enum.all?(
        [
          :profile_digest,
          :adapter_release_digest,
          :local_release_digest,
          :executable_digest,
          :cli_version,
          :credential_reference_iri,
          :credential_generation,
          :revisions,
          :infrastructure
        ],
        &(current[&1] == receipt[&1])
      )
  rescue
    _error -> false
  end

  def current?(_receipt, _current, _at), do: false

  defp infrastructure(infrastructure) when is_map(infrastructure) do
    revisions = CodexLocalRelease.revisions()

    if Enum.sort(Map.keys(infrastructure)) == Enum.sort(@component_fields) and
         Enum.all?(@component_fields, fn field ->
           case infrastructure[field] do
             %{ready: ready, revision: revision}
             when is_boolean(ready) and is_binary(revision) ->
               revision == revisions[field]

             _invalid ->
               false
           end
         end) do
      :ok
    else
      :error
    end
  end

  defp infrastructure(_infrastructure), do: :error
  defp ready?(infrastructure), do: Enum.all?(@component_fields, &infrastructure[&1].ready)

  defp credential_reference(attributes) do
    value = attributes[:credential_reference_iri]

    if is_binary(value) and byte_size(value) <= 512 and
         String.starts_with?(value, "https://jido.run/id/"),
       do: :ok,
       else: :error
  end

  defp probe?(module) when is_atom(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :login_status, 2) and
      module != CodexReadinessProbe
  end

  defp probe?(_module), do: false

  defp executable_registry?(module) when is_atom(module),
    do: Code.ensure_loaded?(module) and function_exported?(module, :resolve, 1)

  defp executable_registry?(_module), do: false

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
