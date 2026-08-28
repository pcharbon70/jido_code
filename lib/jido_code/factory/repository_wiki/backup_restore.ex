defmodule JidoCode.Factory.RepositoryWiki.BackupRestore do
  @moduledoc """
  Bounded multi-repository backup/restore qualification orchestration.

  Durable data remains in the existing store backup. This module only drives
  injected backup, restore, disposable-index rebuild, eligible-maintainer
  restart, and exact fence verification ports.
  """

  alias JidoCode.Knowledge

  @required_ports [:backup, :restore, :rebuild, :restart, :verify]
  @maximum_repositories 100

  @spec execute([map()], map(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def execute(repositories, snapshot, ports, options \\ [])

  def execute(repositories, snapshot, ports, options)
      when is_list(repositories) and is_map(snapshot) and is_map(ports) and is_list(options) and
             repositories != [] and length(repositories) <= @maximum_repositories do
    concurrency = Keyword.get(options, :concurrency, 4)

    with :ok <- validate(repositories, snapshot, ports, concurrency),
         {:ok, backup} <- ports.backup.(snapshot),
         {:ok, restored} <- ports.restore.(backup, snapshot),
         results <- run_repositories(repositories, restored, ports, concurrency),
         {:ok, repository_results} <- collect_results(results) do
      evidence = %{
        backup_digest: backup.digest,
        restored_dataset_revision: restored.dataset_revision,
        repository_count: length(repository_results),
        repositories: repository_results
      }

      {:ok, Map.put(evidence, :digest, Knowledge.repository_wiki_digest(evidence))}
    else
      {:error, reason} -> {:error, redacted_failure(reason)}
      _invalid -> {:error, %{outcome: :invalid_restore_evidence}}
    end
  rescue
    _error -> {:error, %{outcome: :restore_orchestration_failed}}
  end

  def execute(_repositories, _snapshot, _ports, _options),
    do: {:error, %{outcome: :invalid_restore_evidence}}

  defp run_repositories(repositories, restored, ports, concurrency) do
    repositories
    |> Enum.sort_by(&{&1.tenant_iri, &1.repository_iri})
    |> Task.async_stream(
      fn repository -> restore_repository(repository, restored, ports) end,
      max_concurrency: concurrency,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.map(fn
      {:ok, result} -> result
      {:exit, _reason} -> {:error, :worker_failed}
    end)
  end

  defp collect_results(results) do
    case Enum.find(results, &match?({:error, _reason}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, result} -> result end)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp restore_repository(repository, restored, ports) do
    with {:ok, rebuilt} <- ports.rebuild.(repository, restored),
         :ok <- exact_scope(rebuilt, repository),
         {:ok, restarted} <- ports.restart.(repository, rebuilt),
         :ok <- exact_scope(restarted, repository),
         {:ok, verification} <- ports.verify.(repository, restored, rebuilt, restarted),
         :ok <- verify_fences(verification, repository) do
      result = %{
        repository_iri: repository.repository_iri,
        tenant_iri: repository.tenant_iri,
        graph_digest: verification.graph_digest,
        current_edition_iri: verification.current_edition_iri,
        source_fence: verification.source_fence,
        accounting_digest: verification.accounting_digest,
        maintainer: restarted.state,
        projections_rebuilt?: rebuilt.disposable_projections? == true,
        verified?: true
      }

      {:ok, Map.put(result, :digest, Knowledge.repository_wiki_digest(result))}
    else
      {:error, reason} -> {:error, reason}
      _invalid -> {:error, :fence_mismatch}
    end
  end

  defp validate(repositories, snapshot, ports, concurrency) do
    resource_keys = ~w[repository_iri tenant_iri current_edition_iri]a

    cond do
      not (is_integer(concurrency) and concurrency in 1..16) ->
        {:error, :invalid_concurrency}

      not Enum.all?(@required_ports, &is_function(ports[&1])) ->
        {:error, :missing_port}

      not (is_binary(snapshot[:digest]) and byte_size(snapshot.digest) == 64 and
             is_integer(snapshot[:dataset_revision]) and snapshot.dataset_revision >= 0) ->
        {:error, :invalid_snapshot}

      not Enum.all?(repositories, fn repository ->
        is_map(repository) and
          Enum.all?(resource_keys, &(Knowledge.validate_resource_identity(repository[&1]) == :ok)) and
          is_binary(repository[:source_fence]) and
          is_binary(repository[:accounting_digest]) and
          is_integer(repository[:enrollment_revision]) and repository.enrollment_revision >= 0 and
          is_integer(repository[:cancellation_generation]) and
            repository.cancellation_generation >= 0
      end) ->
        {:error, :invalid_repository}

      length(Enum.uniq_by(repositories, &{&1.tenant_iri, &1.repository_iri})) !=
          length(repositories) ->
        {:error, :duplicate_scope}

      true ->
        :ok
    end
  end

  defp exact_scope(value, repository) when is_map(value) do
    if value[:repository_iri] == repository.repository_iri and
         value[:tenant_iri] == repository.tenant_iri do
      :ok
    else
      {:error, :cross_scope}
    end
  end

  defp exact_scope(_value, _repository), do: {:error, :invalid_scope}

  defp verify_fences(verification, repository) do
    if verification[:repository_iri] == repository.repository_iri and
         verification[:tenant_iri] == repository.tenant_iri and
         verification[:current_edition_iri] == repository.current_edition_iri and
         verification[:source_fence] == repository.source_fence and
         verification[:accounting_digest] == repository.accounting_digest and
         verification[:enrollment_revision] == repository.enrollment_revision and
         verification[:cancellation_generation] == repository.cancellation_generation and
         verification[:current_count] == 1 do
      :ok
    else
      {:error, :restore_drift}
    end
  end

  defp redacted_failure(reason)
       when reason in [
              :invalid_concurrency,
              :missing_port,
              :invalid_snapshot,
              :invalid_repository,
              :duplicate_scope,
              :worker_failed,
              :cross_scope,
              :invalid_scope,
              :fence_mismatch,
              :restore_drift
            ],
       do: %{outcome: reason}

  defp redacted_failure(_reason), do: %{outcome: :restore_orchestration_failed}
end
