defmodule JidoCode.Factory.SourceAnalysis.Result do
  @moduledoc "Bounded RDF source-analysis result without publication authority."

  alias JidoCode.Knowledge.Error

  @derive {Inspect,
           only: [
             :analyzer_version,
             :configuration_digest,
             :input_tree_digest,
             :coverage,
             :warnings,
             :resource_counts
           ]}
  @enforce_keys [
    :dataset,
    :analyzer_version,
    :configuration_digest,
    :input_tree_digest,
    :coverage,
    :warnings,
    :resource_counts
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with %RDF.Dataset{} = dataset <- attributes[:dataset],
         true <- valid_text?(attributes[:analyzer_version], 128),
         true <- digest?(attributes[:configuration_digest]),
         true <- git_digest?(attributes[:input_tree_digest]),
         %{status: status} = coverage when status in [:complete, :partial, :incomplete] <-
           attributes[:coverage],
         true <- is_list(attributes[:warnings]) and length(attributes[:warnings]) <= 100,
         true <-
           is_map(attributes[:resource_counts]) and map_size(attributes[:resource_counts]) <= 20,
         true <-
           Enum.all?(attributes[:resource_counts], fn {_key, value} ->
             is_integer(value) and value >= 0
           end) do
      {:ok,
       %__MODULE__{
         dataset: dataset,
         analyzer_version: attributes[:analyzer_version],
         configuration_digest: attributes[:configuration_digest],
         input_tree_digest: String.downcase(attributes[:input_tree_digest]),
         coverage: coverage,
         warnings: Enum.map(attributes[:warnings], &to_string/1),
         resource_counts: attributes[:resource_counts]
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :source_analysis_result)}
    end
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :source_analysis_result)}

  defp valid_text?(value, maximum), do: is_binary(value) and byte_size(value) in 1..maximum
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp git_digest?(value) do
    is_binary(value) and byte_size(value) in [40, 64] and Regex.match?(~r/^[a-f0-9]+$/, value)
  end
end
