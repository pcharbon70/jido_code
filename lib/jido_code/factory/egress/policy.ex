defmodule JidoCode.Factory.Egress.Policy do
  @moduledoc "Closed graph-derived authority for bounded authenticated egress."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Egress.Destination
  alias JidoCode.Knowledge

  @derive {Inspect,
           only: [
             :policy_iri,
             :destinations,
             :methods,
             :allowed_integrity,
             :allowed_confidentiality,
             :maximum_request_bytes,
             :maximum_response_bytes,
             :maximum_redirects,
             :rate_limit,
             :expires_at
           ]}
  @enforce_keys [
    :policy_iri,
    :attempt_iri,
    :invocation_iri,
    :lease_iri,
    :fencing_token,
    :profile_revision,
    :egress_revision,
    :revocation_generation,
    :destinations,
    :methods,
    :allowed_integrity,
    :allowed_confidentiality,
    :maximum_request_bytes,
    :maximum_response_bytes,
    :maximum_redirects,
    :rate_limit,
    :resolver_identity,
    :expires_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @methods [:get, :head, :post, :put, :patch, :delete]
  @integrity [:untrusted, :verified, :trusted]
  @confidentiality [:public, :internal, :restricted]

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resource(attributes[:policy_iri]),
         :ok <- resource(attributes[:attempt_iri]),
         :ok <- resource(attributes[:invocation_iri]),
         :ok <- resource(attributes[:lease_iri]),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         true <- revisions?(attributes),
         :ok <- destinations(attributes[:destinations]),
         :ok <- closed_set(attributes[:methods], @methods),
         :ok <- closed_set(attributes[:allowed_integrity], @integrity),
         :ok <- closed_set(attributes[:allowed_confidentiality], @confidentiality),
         request_bytes when is_integer(request_bytes) and request_bytes in 0..10_485_760 <-
           attributes[:maximum_request_bytes],
         response_bytes when is_integer(response_bytes) and response_bytes in 1..104_857_600 <-
           attributes[:maximum_response_bytes],
         redirects when is_integer(redirects) and redirects in 0..5 <-
           attributes[:maximum_redirects],
         :ok <- rate_limit(attributes[:rate_limit]),
         :ok <- resolver_identity(attributes[:resolver_identity]),
         %DateTime{} <- attributes[:expires_at] do
      values =
        attributes
        |> Map.take(@enforce_keys)
        |> Map.update!(
          :destinations,
          &Enum.sort_by(&1, fn destination ->
            {destination.host, destination.port, destination.path_prefix}
          end)
        )
        |> Map.update!(:methods, &Enum.sort/1)
        |> Map.update!(:allowed_integrity, &Enum.sort/1)
        |> Map.update!(:allowed_confidentiality, &Enum.sort/1)

      {:ok, struct!(__MODULE__, values)}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  defp destinations(values) when is_list(values) and length(values) in 1..16//1 do
    identities =
      Enum.map(values, fn
        %Destination{} = destination ->
          {destination.scheme, destination.host, destination.port, destination.path_prefix}

        _invalid ->
          :invalid
      end)

    if :invalid not in identities and identities == Enum.uniq(identities), do: :ok, else: :error
  end

  defp destinations(_values), do: :error

  defp closed_set(values, allowed) when is_list(values) and values != [] do
    if values == Enum.uniq(values) and Enum.all?(values, &(&1 in allowed)), do: :ok, else: :error
  end

  defp closed_set(_values, _allowed), do: :error

  defp rate_limit(%{requests: requests, window_ms: window})
       when is_integer(requests) and requests in 1..10_000 and is_integer(window) and
              window in 1..86_400_000,
       do: :ok

  defp rate_limit(_value), do: :error

  defp revisions?(attributes) do
    Enum.all?(~w[profile_revision egress_revision revocation_generation]a, fn key ->
      value = attributes[key]
      is_integer(value) and value >= 0
    end)
  end

  defp resolver_identity(value) when is_binary(value) do
    if Regex.match?(~r/^[A-Za-z0-9_.:-]{1,192}@sha256:[a-f0-9]{64}$/, value),
      do: :ok,
      else: :error
  end

  defp resolver_identity(_value), do: :error
  defp resource(value), do: Knowledge.validate_resource_identity(value)
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :egress_policy)}
end
