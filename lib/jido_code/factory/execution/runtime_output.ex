defmodule JidoCode.Factory.Execution.RuntimeOutput do
  @moduledoc "Bounded runtime outcome containing only durable semantic references."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @outcomes ~w[success failure timeout cancelled rejected]a
  @enforce_keys [:attempt_iri, :outcome_class, :artifact_iris, :usage, :completed_at]
  defstruct @enforce_keys ++ [:diagnostic]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Knowledge.validate_resource_identity(attributes[:attempt_iri]),
         outcome when outcome in @outcomes <- attributes[:outcome_class],
         artifacts when is_list(artifacts) and length(artifacts) <= 100 <-
           attributes[:artifact_iris],
         true <- Enum.all?(artifacts, &(Knowledge.validate_resource_identity(&1) == :ok)),
         usage when is_map(usage) <- attributes[:usage],
         true <- byte_size(:erlang.term_to_binary(usage, [:deterministic])) <= 4_096,
         %DateTime{} = completed_at <- attributes[:completed_at],
         :ok <- optional_diagnostic(attributes[:diagnostic]) do
      {:ok,
       %__MODULE__{
         attempt_iri: attributes.attempt_iri,
         outcome_class: outcome,
         artifact_iris: Enum.sort(artifacts),
         usage: usage,
         completed_at: DateTime.truncate(completed_at, :microsecond),
         diagnostic: attributes[:diagnostic]
       }}
    else
      _invalid -> invalid(:runtime_output)
    end
  rescue
    _error -> invalid(:runtime_output)
  end

  def new(_attributes), do: invalid(:runtime_output)

  defp optional_diagnostic(nil), do: :ok

  defp optional_diagnostic(value) when is_binary(value) and byte_size(value) <= 1_024,
    do: :ok

  defp optional_diagnostic(_value), do: :error

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
