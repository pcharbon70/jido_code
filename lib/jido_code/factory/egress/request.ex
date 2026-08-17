defmodule JidoCode.Factory.Egress.Request do
  @moduledoc "Bounded egress request whose policy is re-evaluated by the broker."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Egress.Policy

  @derive {Inspect,
           only: [
             :method,
             :traffic_class,
             :integrity,
             :confidentiality,
             :request_bytes,
             :redirect_count
           ]}
  @enforce_keys [
    :policy,
    :uri,
    :method,
    :traffic_class,
    :integrity,
    :confidentiality,
    :request_bytes,
    :redirect_count
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @methods [:get, :head, :post, :put, :patch, :delete]
  @traffic_classes [:provider_api, :package_registry]
  @integrity [:untrusted, :verified, :trusted]
  @confidentiality [:public, :internal, :restricted]

  @spec new(Policy.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%Policy{} = policy, attributes) when is_map(attributes) do
    with uri when is_binary(uri) and byte_size(uri) in 1..2_048 <- attributes[:uri],
         method when method in @methods <- attributes[:method],
         traffic when traffic in @traffic_classes <- attributes[:traffic_class],
         integrity when integrity in @integrity <- attributes[:integrity],
         confidentiality when confidentiality in @confidentiality <- attributes[:confidentiality],
         bytes when is_integer(bytes) and bytes in 0..10_485_760 <- attributes[:request_bytes],
         redirects when is_integer(redirects) and redirects in 0..5 <-
           Map.get(attributes, :redirect_count, 0) do
      {:ok,
       %__MODULE__{
         policy: policy,
         uri: uri,
         method: method,
         traffic_class: traffic,
         integrity: integrity,
         confidentiality: confidentiality,
         request_bytes: bytes,
         redirect_count: redirects
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_policy, _attributes), do: invalid()
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :egress_request)}
end
