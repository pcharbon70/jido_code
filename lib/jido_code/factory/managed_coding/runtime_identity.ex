defmodule JidoCode.Factory.ManagedCoding.RuntimeIdentity do
  @moduledoc """
  Product identity of one disposable runtime projection.

  Equality requires both the durable attempt IRI and fencing token. A process
  restarted under the same pair is equivalent execution material; any higher
  fence supersedes it and any lower fence is stale.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @enforce_keys [:attempt_iri, :fencing_token]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(String.t(), pos_integer()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attempt_iri, fencing_token) do
    with :ok <- Knowledge.validate_resource_identity(attempt_iri),
         true <- is_integer(fencing_token) and fencing_token > 0 do
      {:ok, %__MODULE__{attempt_iri: attempt_iri, fencing_token: fencing_token}}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :runtime_identity)}
    end
  end

  @spec compare(t(), t()) :: :current | :stale | :superseding | :different_attempt
  def compare(%__MODULE__{attempt_iri: attempt}, %__MODULE__{attempt_iri: other})
      when attempt != other,
      do: :different_attempt

  def compare(%__MODULE__{fencing_token: fence}, %__MODULE__{fencing_token: fence}), do: :current

  def compare(%__MODULE__{fencing_token: fence}, %__MODULE__{fencing_token: current})
      when fence < current,
      do: :stale

  def compare(%__MODULE__{}, %__MODULE__{}), do: :superseding
end
