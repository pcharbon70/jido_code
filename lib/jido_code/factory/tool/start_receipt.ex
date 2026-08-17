defmodule JidoCode.Factory.Tool.StartReceipt do
  @moduledoc "Accepted durable start receipt with opaque outcome-recording context."

  alias JidoCode.Factory.AdapterError

  @derive {Inspect, only: [:invocation_iri, :authorization_digest, :outcome]}
  @enforce_keys [:invocation_iri, :authorization_digest, :outcome, :opaque]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with invocation when is_binary(invocation) <- attributes[:invocation_iri],
         digest when is_binary(digest) <- attributes[:authorization_digest],
         true <- Regex.match?(~r/^[a-f0-9]{64}$/, digest),
         outcome when outcome in [:committed, :idempotent] <- attributes[:outcome],
         true <- Map.has_key?(attributes, :opaque) do
      {:ok,
       %__MODULE__{
         invocation_iri: invocation,
         authorization_digest: digest,
         outcome: outcome,
         opaque: attributes.opaque
       }}
    else
      _invalid -> invalid()
    end
  end

  def new(_attributes), do: invalid()
  defp invalid, do: {:error, AdapterError.new(:corrupt, :tool_start_receipt)}
end
