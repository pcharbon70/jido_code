defmodule JidoCode.Integrations.DelegatedRegisteredChecks do
  @moduledoc "Controller-selected authoritative checks after delegated turn boundaries."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CheckCatalog
  alias JidoCode.Factory.ManagedCoding.CheckDefinition
  alias JidoCode.Factory.ManagedCoding.MutationRequest
  alias JidoCode.Factory.ManagedCoding.WorkspaceDigest
  alias JidoCode.Integrations.ManagedCodingCandidateTools

  @boundaries [:completed_turn, :handoff]

  @spec run(MutationRequest.t(), map(), map(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def run(%MutationRequest{} = request, event, authority, options)
      when is_map(event) and is_map(authority) and is_list(options) do
    with boundary when boundary in @boundaries <- event[:boundary],
         true <- event[:observation_trust] == :untrusted,
         true <- authority?(request, authority),
         %CheckCatalog{} = catalog <- Keyword.get(options, :check_catalog),
         true <- authority[:catalog_revision] == catalog.revision,
         checks when is_list(checks) and checks != [] <- authority[:registered_checks],
         true <- checks == Enum.uniq(checks),
         {:ok, definitions} <- definitions(catalog, checks),
         {:ok, check_environment} <- workspace_ready(request, options),
         {:ok, receipts} <-
           run_checks(request, definitions, authority, options, check_environment) do
      result = %{
        boundary: boundary,
        observation_trust: :untrusted,
        observation_digest: WorkspaceDigest.digest(Map.get(event, :observations, [])),
        authoritative_checks: receipts,
        catalog_revision: catalog.revision,
        attempt_iri: request.attempt_iri,
        fencing_token: request.fencing_token,
        workspace_iri: request.workspace_iri,
        source_snapshot_iri: request.snapshot_iri
      }

      {:ok, Map.put(result, :receipt_digest, WorkspaceDigest.digest(result))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> unauthorized(:delegated_registered_checks)
    end
  rescue
    _error -> unavailable(:delegated_registered_checks)
  end

  def run(_request, _event, _authority, _options),
    do: invalid(:delegated_registered_checks)

  defp definitions(catalog, checks) do
    Enum.reduce_while(checks, {:ok, []}, fn name, {:ok, values} ->
      case CheckCatalog.fetch(catalog, name) do
        {:ok, definition} -> {:cont, {:ok, [definition | values]}}
        {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp run_checks(request, definitions, authority, options, check_environment) do
    runner = Keyword.get(options, :check_runner)

    protected_runner = fn command, timeout ->
      runner.(
        %{command | environment: Map.merge(command.environment, check_environment)},
        timeout
      )
    end

    options = Keyword.put(options, :check_runner, protected_runner)

    Enum.reduce_while(definitions, {:ok, []}, fn definition, {:ok, receipts} ->
      case ManagedCodingCandidateTools.run_registered_check(
             request,
             %{check: definition.name},
             options
           ) do
        {:ok, result} ->
          receipt = receipt(request, definition, result, authority)
          {:cont, {:ok, [receipt | receipts]}}

        {:error, %AdapterError{} = error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, receipts} -> {:ok, Enum.reverse(receipts)}
      error -> error
    end
  end

  defp receipt(request, definition, result, authority) do
    receipt = %{
      attempt_iri: request.attempt_iri,
      lease_iri: request.lease_iri,
      fencing_token: request.fencing_token,
      source_snapshot_iri: request.snapshot_iri,
      workspace_iri: request.workspace_iri,
      workspace_digest: request.workspace_digest,
      profile_revision: authority.profile_revision,
      check: definition.name,
      check_revision: result.check_revision,
      command_digest: CheckDefinition.digest(definition),
      limits: %{
        timeout_ms: definition.timeout_ms,
        output_bytes: definition.output_bytes,
        resources: definition.resources,
        network: definition.network
      },
      status: result.status,
      exit_code: result.exit_code,
      duration_ms: result.duration_ms,
      output_digest: WorkspaceDigest.digest(result.output),
      output_bytes: byte_size(result.output),
      truncated?: result.truncated?,
      redacted?: result.redacted?,
      catalog_revision: result.catalog_revision
    }

    Map.put(receipt, :receipt_digest, WorkspaceDigest.digest(receipt))
  end

  defp workspace_ready(request, options) do
    with provider when is_function(provider, 0) <- Keyword.get(options, :workspace_provider),
         current when is_map(current) <- provider.(),
         :ready <- current[:status],
         true <- current[:iri] == request.workspace_iri,
         true <- current[:root] == request.workspace_root,
         true <- current[:workspace_digest] == request.workspace_digest,
         environment_provider when is_function(environment_provider, 0) <-
           Keyword.get(options, :check_environment_provider),
         environment when is_map(environment) <- environment_provider.(),
         true <- valid_check_environment?(environment),
         runner when is_function(runner, 2) <- Keyword.get(options, :check_runner) do
      {:ok, environment}
    else
      _invalid -> unauthorized(:delegated_registered_check_workspace)
    end
  end

  defp valid_check_environment?(environment) do
    expected =
      ~w[GIT_CONFIG_NOSYSTEM GIT_CONFIG_GLOBAL GIT_TERMINAL_PROMPT GIT_ASKPASS GIT_DIR GIT_WORK_TREE]

    Enum.sort(Map.keys(environment)) == Enum.sort(expected) and
      Enum.all?(environment, fn {key, value} ->
        is_binary(key) and is_binary(value) and byte_size(value) in 1..1_024
      end)
  end

  defp authority?(request, authority) do
    authority[:attempt_iri] == request.attempt_iri and
      authority[:lease_iri] == request.lease_iri and
      authority[:fencing_token] == request.fencing_token and
      authority[:snapshot_iri] == request.snapshot_iri and
      authority[:workspace_iri] == request.workspace_iri and
      authority[:policy_revision] == request.policy_revision and
      is_binary(authority[:profile_revision]) and byte_size(authority.profile_revision) == 64
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
