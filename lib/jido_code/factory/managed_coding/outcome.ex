defmodule JidoCode.Factory.ManagedCoding.Outcome do
  @moduledoc "Bounded graph-reconstructable result returned by the managed coding facade."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @states ~w[admitted preparing running awaiting_actor assembling_candidate candidate_ready verifying dispositioned cancelling cancelled completed failed rejected]a
  @enforce_keys [:attempt_iri, :fencing_token, :state, :sequence, :occurred_at, :references]
  defstruct @enforce_keys ++ [:classification]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Knowledge.validate_resource_identity(attributes[:attempt_iri]),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         state when state in @states <- attributes[:state],
         sequence when is_integer(sequence) and sequence >= 0 <- attributes[:sequence],
         %DateTime{} = occurred_at <- attributes[:occurred_at],
         references when is_list(references) and length(references) <= 64 <-
           attributes[:references],
         true <- Enum.all?(references, &(Knowledge.validate_resource_identity(&1) == :ok)),
         :ok <- optional_classification(attributes[:classification]) do
      {:ok,
       %__MODULE__{
         attempt_iri: attributes.attempt_iri,
         fencing_token: fence,
         state: state,
         sequence: sequence,
         occurred_at: DateTime.truncate(occurred_at, :microsecond),
         references: Enum.sort(Enum.uniq(references)),
         classification: attributes[:classification]
       }}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_outcome)}
    end
  rescue
    _error -> {:error, AdapterError.new(:invalid_input, :managed_coding_outcome)}
  end

  def new(_attributes), do: {:error, AdapterError.new(:invalid_input, :managed_coding_outcome)}

  defp optional_classification(nil), do: :ok

  defp optional_classification(value)
       when value in [:pending, :success, :failure, :cancelled, :rejected], do: :ok

  defp optional_classification(_value), do: :error
end
