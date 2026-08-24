defmodule JidoCode.Factory.ManagedCoding.Budget do
  @moduledoc """
  Immutable limits and enforcement classes for one managed coding profile.

  Every dimension is declared. Safety dimensions require `hard` enforcement;
  metered dimensions may use `next_effect` when the provider reports usage only
  after a bounded call. No production profile can call a required dimension
  unavailable.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Vocabulary

  @dimensions ~w[turns model_calls tokens tool_calls input_bytes output_bytes wall_time_ms idle_time_ms cost_microunits processes memory_bytes disk_bytes changed_files diff_bytes clarification_rounds]a
  @next_effect_allowed ~w[tokens cost_microunits]a
  @enforce_keys @dimensions
  defstruct @enforce_keys

  @type limit :: %{limit: pos_integer(), enforcement: atom()}
  @type t :: %__MODULE__{}

  @spec dimensions() :: [atom()]
  def dimensions, do: @dimensions

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- Enum.sort(Map.keys(attributes)) == Enum.sort(@dimensions),
         true <- Enum.all?(@dimensions, &valid_limit?(&1, attributes[&1])) do
      {:ok, struct!(__MODULE__, Map.take(attributes, @dimensions))}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_budget)}
    end
  rescue
    _error -> {:error, AdapterError.new(:invalid_input, :managed_coding_budget)}
  end

  def new(_attributes), do: {:error, AdapterError.new(:invalid_input, :managed_coding_budget)}

  @spec limit(t(), atom()) :: limit() | nil
  def limit(%__MODULE__{} = budget, dimension) when dimension in @dimensions,
    do: Map.fetch!(budget, dimension)

  def limit(%__MODULE__{}, _dimension), do: nil

  defp valid_limit?(dimension, %{limit: limit, enforcement: enforcement})
       when is_integer(limit) and limit > 0 do
    Vocabulary.valid?(:enforcement_class, enforcement) and
      enforcement != :unavailable and
      (enforcement == :hard or
         (dimension in @next_effect_allowed and enforcement == :next_effect))
  end

  defp valid_limit?(_dimension, _value), do: false
end
