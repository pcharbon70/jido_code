defmodule JidoCode.Factory.SourceAnalysis.Request do
  @moduledoc "Bounded, exact-snapshot input to a source analyzer adapter."

  alias JidoCode.Factory.Observations.GitSnapshot
  alias JidoCode.Factory.Observations.Worktree
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @derive {Inspect,
           only: [
             :repository_iri,
             :snapshot_iri,
             :profile,
             :input_tree_digest,
             :ontology_version,
             :limits
           ]}
  @enforce_keys [
    :repository_iri,
    :snapshot_iri,
    :worktree,
    :git_snapshot,
    :profile,
    :include_paths,
    :exclude_paths,
    :limits,
    :ontology_version,
    :output_graph_iri,
    :input_tree_digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @defaults %{
    max_files: 100,
    max_total_bytes: 5_000_000,
    max_file_bytes: 500_000,
    max_symbols: 100,
    max_expressions: 100_000,
    max_statements: 400,
    timeout_ms: 10_000
  }

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    limits = Map.merge(@defaults, Map.get(attributes, :limits, %{}))

    with :ok <- Knowledge.validate_resource_identity(attributes[:repository_iri]),
         :ok <- Knowledge.validate_resource_identity(attributes[:snapshot_iri]),
         %Worktree{} = worktree <- attributes[:worktree],
         %GitSnapshot{} = git_snapshot <- attributes[:git_snapshot],
         true <- verified_snapshot?(attributes, git_snapshot),
         :elixir <- attributes[:profile],
         {:ok, include_paths} <- paths(Map.get(attributes, :include_paths, ["lib", "test"])),
         {:ok, exclude_paths} <- paths(Map.get(attributes, :exclude_paths, ["deps", "_build"])),
         true <- valid_limits?(limits),
         "1.0.0" <- attributes[:ontology_version],
         {:ok, :source_revision} <-
           Knowledge.validate_graph_identity(attributes[:output_graph_iri]),
         true <- git_digest?(attributes[:input_tree_digest]) do
      {:ok,
       %__MODULE__{
         repository_iri: attributes[:repository_iri],
         snapshot_iri: attributes[:snapshot_iri],
         worktree: worktree,
         git_snapshot: git_snapshot,
         profile: :elixir,
         include_paths: include_paths,
         exclude_paths: exclude_paths,
         limits: limits,
         ontology_version: "1.0.0",
         output_graph_iri: attributes[:output_graph_iri],
         input_tree_digest: String.downcase(attributes[:input_tree_digest])
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :source_analysis_request)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :source_analysis_request)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :source_analysis_request)}

  defp paths(values) when is_list(values) and length(values) <= 100 do
    if Enum.all?(values, &valid_path?/1),
      do: {:ok, values |> Enum.uniq() |> Enum.sort()},
      else: {:error, Error.new(:invalid_input, :source_analysis_paths)}
  end

  defp paths(_values), do: {:error, Error.new(:invalid_input, :source_analysis_paths)}

  defp valid_path?(value) do
    is_binary(value) and byte_size(value) in 1..256 and Path.type(value) != :absolute and
      not (value |> String.split(["/", "\\"]) |> Enum.any?(&(&1 in [".", ".."])))
  end

  defp valid_limits?(limits) do
    map_size(limits) == map_size(@defaults) and
      Enum.all?(@defaults, fn {key, _default} ->
        case {key, Map.get(limits, key)} do
          {:timeout_ms, value} -> is_integer(value) and value in 100..60_000
          {:max_total_bytes, value} -> is_integer(value) and value in 1_024..50_000_000
          {:max_file_bytes, value} -> is_integer(value) and value in 1_024..2_000_000
          {:max_statements, value} -> is_integer(value) and value in 20..800
          {_key, value} -> is_integer(value) and value in 1..200_000
        end
      end) and limits.max_file_bytes <= limits.max_total_bytes
  end

  defp git_digest?(value) do
    is_binary(value) and byte_size(value) in [40, 64] and Regex.match?(~r/^[a-fA-F0-9]+$/, value)
  end

  defp verified_snapshot?(attributes, snapshot) do
    algorithm = snapshot.object_format

    identity_matches? =
      case Knowledge.repository_snapshot_identity(
             attributes[:repository_iri],
             algorithm,
             snapshot.tree_sha
           ) do
        {:ok, expected} -> expected == attributes[:snapshot_iri]
        {:error, _error} -> false
      end

    snapshot.clean? and snapshot.tree_sha == String.downcase(attributes[:input_tree_digest]) and
      identity_matches?
  end
end
