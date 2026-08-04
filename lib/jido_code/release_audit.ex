defmodule JidoCode.ReleaseAudit do
  @moduledoc "Release-candidate audit for graph-only durable authority."

  alias JidoCode.Architecture.Checker
  alias JidoCode.Knowledge.Error
  alias JidoCode.ReleaseContract

  @source_globs [
    "lib/**/*",
    "assets/**/*",
    "config/**/*",
    "priv/ontology/**/*",
    "mix.exs",
    "mix.lock"
  ]
  @forbidden_dependencies ~w[
    ecto ecto_sql cubdb redix postgrex mongodb level rocksdb_ex broadway oban
  ]

  @spec run(Path.t()) :: {:ok, map()} | {:error, Error.t()}
  def run(root \\ File.cwd!())

  def run(root) when is_binary(root) do
    with :ok <- ReleaseContract.verify(),
         {:ok, []} <- Checker.check(root),
         :ok <- dependency_audit(root),
         {:ok, digest, file_count} <- source_manifest(root) do
      {:ok,
       %{
         status: :accepted,
         release_contract_digest: ReleaseContract.digest(),
         source_manifest_sha256: digest,
         source_file_count: file_count,
         durable_store_count: 1,
         durable_store: :triple_store,
         hidden_authority_findings: 0,
         compatibility_facades: 0,
         representative_traces: representative_traces()
       }}
    else
      {:error, [_ | _]} -> {:error, Error.new(:incompatible, :release_architecture_audit)}
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:incompatible, :release_architecture_audit)}
    end
  end

  def run(_root), do: {:error, Error.new(:invalid_input, :release_architecture_audit)}

  defp dependency_audit(root) do
    lock_path = Path.join(root, "mix.lock")

    case File.read(lock_path) do
      {:ok, lock} ->
        forbidden = Enum.filter(@forbidden_dependencies, &Regex.match?(~r/"#{&1}"\s*=>/, lock))

        if forbidden == [],
          do: :ok,
          else: {:error, Error.new(:incompatible, :release_dependency_audit)}

      {:error, _reason} ->
        {:error, Error.new(:unavailable, :release_dependency_audit)}
    end
  end

  defp source_manifest(root) do
    files =
      @source_globs
      |> Enum.flat_map(&Path.wildcard(Path.join(root, &1)))
      |> Enum.filter(&File.regular?/1)
      |> Enum.uniq()
      |> Enum.sort()

    digest =
      files
      |> Enum.map(fn file ->
        relative = Path.relative_to(file, root)
        contents = File.read!(file)
        {relative, :crypto.hash(:sha256, contents)}
      end)
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    {:ok, digest, length(files)}
  rescue
    _error -> {:error, Error.new(:unavailable, :release_source_manifest)}
  end

  defp representative_traces do
    [
      %{fact: :repository_enrollment, command: "EnrollRepository", graph: :factory_catalog},
      %{fact: :current_work_state, command: "TransitionControlState", graph: :repository_control},
      %{fact: :execution_outcome, command: "FinalizeExecutionRun", graph: :run_attempt},
      %{fact: :accepted_decision, command: "RecordGoalOutcome", graph: :evidence},
      %{fact: :accepted_knowledge, command: "AdoptKnowledgeAssertion", graph: :memory}
    ]
  end
end
