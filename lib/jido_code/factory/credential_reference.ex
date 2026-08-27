defmodule JidoCode.Factory.CredentialReference do
  @moduledoc """
  Opaque reference passed to a secret provider at adapter call time.

  The reference contains no credential bytes and is safe to retain in
  transient adapter configuration or graph provenance.
  """

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @derive {Inspect, only: [:iri, :provider]}
  @enforce_keys [:iri, :provider, :key]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Knowledge.validate_resource_identity(attributes[:iri]),
         true <- valid_text?(attributes[:provider], 64),
         true <- valid_text?(attributes[:key], 160),
         false <- secret_material?(attributes[:key]) do
      {:ok,
       %__MODULE__{
         iri: attributes[:iri],
         provider: attributes[:provider],
         key: attributes[:key]
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :credential_reference)}
    end
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :credential_reference)}

  @spec durable_record(t(), pos_integer()) :: map()
  def durable_record(%__MODULE__{} = reference, revocation_generation)
      when is_integer(revocation_generation) and revocation_generation > 0 do
    %{
      iri: reference.iri,
      provider: reference.provider,
      revocation_generation: revocation_generation
    }
  end

  defp valid_text?(value, maximum) do
    is_binary(value) and byte_size(value) in 1..maximum and
      not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
  end

  defp secret_material?(value) do
    String.starts_with?(String.downcase(value), ["bearer ", "token ", "basic "])
  end
end
