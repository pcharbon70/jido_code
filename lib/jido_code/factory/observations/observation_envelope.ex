defmodule JidoCode.Factory.Observations.ObservationEnvelope do
  @moduledoc """
  Normalized polling or webhook ingress value.

  Both ingress modes use the same bounded contract and stable delivery
  identity. The envelope is not a durable queue item and contains no command or
  graph-placement authority.
  """

  alias JidoCode.Factory.Observations.ProviderObservation
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @enforce_keys [
    :source,
    :delivery_identity,
    :enrollment_iri,
    :locator_iri,
    :received_at,
    :source_time,
    :observations,
    :completeness,
    :warnings
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with source when source in [:poll, :webhook] <- attributes[:source],
         true <- delivery_identity?(attributes[:delivery_identity]),
         :ok <- Knowledge.validate_resource_identity(attributes[:enrollment_iri]),
         :ok <- Knowledge.validate_resource_identity(attributes[:locator_iri]),
         %DateTime{} = received_at <- attributes[:received_at],
         true <-
           is_nil(attributes[:source_time]) or match?(%DateTime{}, attributes[:source_time]),
         true <-
           is_list(attributes[:observations]) and length(attributes[:observations]) in 1..500,
         true <- Enum.all?(attributes[:observations], &match?(%ProviderObservation{}, &1)),
         %{status: status} = completeness when status in [:complete, :partial, :unknown] <-
           attributes[:completeness],
         true <- is_list(attributes[:warnings]) and length(attributes[:warnings]) <= 50 do
      {:ok,
       %__MODULE__{
         source: source,
         delivery_identity: attributes[:delivery_identity],
         enrollment_iri: attributes[:enrollment_iri],
         locator_iri: attributes[:locator_iri],
         received_at: DateTime.truncate(received_at, :microsecond),
         source_time: truncate(attributes[:source_time]),
         observations: attributes[:observations],
         completeness: completeness,
         warnings: Enum.map(attributes[:warnings], &to_string/1)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec delivery_identity([String.t()]) :: String.t()
  def delivery_identity(parts) when is_list(parts) and parts != [] do
    parts
    |> Enum.join("\n")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp delivery_identity?(value),
    do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp truncate(nil), do: nil
  defp truncate(time), do: DateTime.truncate(time, :microsecond)
  defp invalid, do: {:error, Error.new(:invalid_input, :observation_envelope)}
end
