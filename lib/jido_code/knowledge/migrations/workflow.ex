defmodule JidoCode.Knowledge.Migrations.Workflow do
  @moduledoc "Bounded, graph-rebuildable release migration planning and execution."

  alias JidoCode.Knowledge.BackupReceipt
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.IntegrityReport
  alias JidoCode.ReleaseContract

  @version_keys %{
    application: :application,
    ontology: :ontology,
    shapes: :shapes,
    query_catalog: :query_catalog,
    reasoning: :reasoning_digest,
    backend_schema: :backend_schema,
    store_schema: :store_schema
  }

  @spec plan(map(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def plan(current, target, options \\ [])

  def plan(current, target, options)
      when is_map(current) and is_map(target) and is_list(options) do
    with true <- valid_manifest?(current),
         true <- valid_manifest?(target),
         {:ok, estimated_bytes} <- estimated_bytes(options) do
      changed =
        ReleaseContract.migration_order()
        |> Enum.filter(&changed?(&1, current, target))

      {:ok,
       %{
         id: migration_id(current, target),
         source_digest: manifest_digest(current),
         target_digest: manifest_digest(target),
         steps: changed,
         destructive?:
           Enum.any?(changed, &(&1 in [:ontology, :backend_schema, :store_schema, :graphs])),
         estimated_bytes: estimated_bytes,
         rollback_posture: :verified_checkpoint,
         execution_mode: :maintenance,
         state_source: :graph
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :release_migration_plan)}
    end
  end

  def plan(_current, _target, _options),
    do: {:error, Error.new(:invalid_input, :release_migration_plan)}

  @spec preflight(map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def preflight(plan, evidence) when is_map(plan) and is_map(evidence) do
    with %IntegrityReport{status: :ok, issues: []} <- evidence[:integrity],
         :ok <- backup_evidence(plan, evidence[:backup]),
         true <-
           is_integer(evidence[:free_bytes]) and evidence.free_bytes >= required_bytes(plan),
         true <- evidence[:maintenance_available?] == true do
      {:ok,
       %{
         migration_id: plan.id,
         rollback_artifact: backup_id(evidence[:backup]),
         required_bytes: required_bytes(plan),
         accepted?: true
       }}
    else
      _invalid -> {:error, Error.new(:conflict, :release_migration_preflight)}
    end
  end

  def preflight(_plan, _evidence),
    do: {:error, Error.new(:invalid_input, :release_migration_preflight)}

  @spec execute(map(), (atom() -> {:ok, term()} | {:error, Error.t()})) ::
          {:ok, map()} | {:error, Error.t()}
  def execute(%{steps: steps, id: id, target_digest: digest}, runner)
      when is_list(steps) and is_function(runner, 1) do
    Enum.reduce_while(steps, {:ok, []}, fn step, {:ok, receipts} ->
      case runner.(step) do
        {:ok, receipt} -> {:cont, {:ok, [{step, receipt} | receipts]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
        _invalid -> {:halt, {:error, Error.new(:unavailable, :release_migration_step)}}
      end
    end)
    |> case do
      {:ok, receipts} ->
        {:ok,
         %{
           migration_id: id,
           target_digest: digest,
           completed_steps: receipts |> Enum.reverse() |> Enum.map(&elem(&1, 0)),
           state: :complete
         }}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  def execute(_plan, _runner), do: {:error, Error.new(:invalid_input, :release_migration)}

  defp valid_manifest?(manifest) do
    required = Map.values(@version_keys)

    Enum.all?(required, &Map.has_key?(manifest, &1)) and
      Enum.all?(manifest, fn
        {_key, value} when is_binary(value) -> byte_size(value) in 1..256
        {_key, value} when is_integer(value) -> value >= 0
        {_key, _value} -> false
      end)
  end

  defp changed?(:graphs, current, target), do: changed?(:ontology, current, target)
  defp changed?(:derived_rebuild, current, target), do: changed?(:reasoning, current, target)

  defp changed?(:acceptance, current, target),
    do: manifest_digest(current) != manifest_digest(target)

  defp changed?(step, current, target) do
    case Map.fetch(@version_keys, step) do
      {:ok, key} -> current[key] != target[key]
      :error -> false
    end
  end

  defp backup_evidence(%{destructive?: false}, nil), do: :ok

  defp backup_evidence(_plan, %BackupReceipt{payload_sha256: digest})
       when is_binary(digest) and byte_size(digest) == 64,
       do: :ok

  defp backup_evidence(_plan, _backup),
    do: {:error, Error.new(:conflict, :release_migration_backup)}

  defp required_bytes(plan), do: if(plan.destructive?, do: plan.estimated_bytes * 2, else: 0)
  defp backup_id(nil), do: nil
  defp backup_id(%BackupReceipt{artifact_id: artifact_id}), do: artifact_id

  defp estimated_bytes(options) do
    case Keyword.get(options, :estimated_bytes, 0) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _invalid -> {:error, Error.new(:invalid_input, :release_migration_size)}
    end
  end

  defp migration_id(current, target) do
    "urn:jido-code:migration:" <> String.slice(manifest_digest({current, target}), 0, 32)
  end

  defp manifest_digest(manifest) do
    manifest
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
