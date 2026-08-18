defmodule JidoCode.Factory.Extensions.MultiAgent.Output do
  @moduledoc "One bounded worker result returned only to the Factory coordinator."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.MultiAgent.Plan
  alias JidoCode.Factory.Extensions.MultiAgent.Specification
  alias JidoCode.Factory.Tool.Definition

  @keys [:plan_digest, :worker_iri, :output, :output_digest, :output_bytes, :completed_at]
  @enforce_keys @keys ++ [:bounded, :coordinator_only, :accepted, :digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Specification.t(), Plan.t(), map()) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def new(%Specification{} = specification, %Plan{} = plan, attributes)
      when is_map(attributes) do
    with true <- Plan.valid?(plan, specification),
         true <- exact_shape?(attributes, @keys),
         true <- attributes[:plan_digest] == plan.digest,
         {:ok, worker} <- Plan.fetch_worker(plan, attributes[:worker_iri]),
         {:ok, output} <-
           Specification.validate_output(
             specification,
             attributes[:output],
             worker.budget.output_bytes
           ),
         output_bytes <- byte_size(:erlang.term_to_binary(output, [:deterministic])),
         true <- attributes[:output_bytes] == output_bytes,
         true <- attributes[:output_digest] == Definition.digest(output),
         %DateTime{} = completed_at <- attributes[:completed_at],
         normalized <-
           attributes
           |> Map.put(:output, output)
           |> Map.put(:completed_at, DateTime.truncate(completed_at, :microsecond)),
         governed <-
           normalized
           |> Map.put(:bounded, true)
           |> Map.put(:coordinator_only, true)
           |> Map.put(:accepted, false),
         digest <- Definition.digest(governed) do
      {:ok, struct!(__MODULE__, Map.put(governed, :digest, digest))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:multi_agent_output)
    end
  rescue
    _error -> invalid(:multi_agent_output)
  end

  def new(_specification, _plan, _attributes), do: invalid(:multi_agent_output)

  @spec valid?(t(), Specification.t(), Plan.t()) :: boolean()
  def valid?(%__MODULE__{} = output, %Specification{} = specification, %Plan{} = plan) do
    attributes = output |> Map.from_struct() |> Map.take(@keys)

    case new(specification, plan, attributes) do
      {:ok, rebuilt} -> rebuilt == output
      {:error, %AdapterError{}} -> false
    end
  end

  def valid?(_output, _specification, _plan), do: false

  @spec collect(Specification.t(), Plan.t(), [t()]) ::
          {:ok, [t()]} | {:error, AdapterError.t()}
  def collect(%Specification{} = specification, %Plan{} = plan, outputs)
      when is_list(outputs) do
    workers = Enum.map(plan.workers, & &1.worker_iri) |> Enum.sort()
    output_workers = Enum.map(outputs, & &1.worker_iri) |> Enum.sort()

    if workers == output_workers and
         Enum.all?(outputs, &valid?(&1, specification, plan)) do
      {:ok, Enum.sort_by(outputs, & &1.worker_iri)}
    else
      invalid(:multi_agent_output_collection)
    end
  rescue
    _error -> invalid(:multi_agent_output_collection)
  end

  def collect(_specification, _plan, _outputs), do: invalid(:multi_agent_output_collection)

  @spec accepting_output?(t()) :: false
  def accepting_output?(%__MODULE__{}), do: false

  defp exact_shape?(value, keys),
    do: MapSet.new(Map.keys(value)) == MapSet.new(keys)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
