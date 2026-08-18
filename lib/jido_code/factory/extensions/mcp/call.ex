defmodule JidoCode.Factory.Extensions.MCP.Call do
  @moduledoc """
  Closed MCP invocation bound to one accepted specification and Phase 3 command.

  The derived command name includes the call digest. A Phase 3 capability must
  therefore authorize this exact call rather than a reusable server-wide verb.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.MCP.Specification
  alias JidoCode.Knowledge

  @keys [
    :specification_digest,
    :namespaced_tool,
    :observed_descriptor_digest,
    :arguments_ref,
    :arguments,
    :arguments_digest,
    :connection
  ]
  @enforce_keys @keys ++ [:tool, :credential_reference_iri, :digest, :authorization_command]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Specification.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%Specification{} = specification, attributes) when is_map(attributes) do
    with true <- Specification.valid?(specification),
         true <- exact_shape?(attributes, @keys),
         true <- attributes[:specification_digest] == specification.digest,
         {:ok, tool} <- Specification.fetch_tool(specification, attributes[:namespaced_tool]),
         true <- attributes[:observed_descriptor_digest] == tool.descriptor_digest,
         :ok <- Knowledge.validate_resource_identity(attributes[:arguments_ref]),
         {:ok, arguments} <- validate_arguments(attributes[:arguments], tool.input_schema),
         false <- secret?(arguments),
         true <- attributes[:arguments_digest] == Specification.digest(arguments),
         {:ok, connection, credential_reference_iri} <-
           connection(specification, attributes[:connection]),
         normalized <-
           attributes
           |> Map.put(:arguments, arguments)
           |> Map.put(:connection, connection),
         digest <- Specification.digest({specification.digest, Map.take(normalized, @keys)}),
         command <- "mcp_" <> String.slice(digest, 7, 60) do
      values =
        normalized
        |> Map.put(:tool, tool)
        |> Map.put(:credential_reference_iri, credential_reference_iri)
        |> Map.put(:digest, digest)
        |> Map.put(:authorization_command, command)

      {:ok, struct!(__MODULE__, values)}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:mcp_call)
    end
  rescue
    _error -> invalid(:mcp_call)
  end

  def new(_specification, _attributes), do: invalid(:mcp_call)

  @spec valid?(t(), Specification.t()) :: boolean()
  def valid?(%__MODULE__{} = call, %Specification{} = specification) do
    attributes = call |> Map.from_struct() |> Map.take(@keys)

    case new(specification, attributes) do
      {:ok, rebuilt} -> rebuilt == call
      {:error, %AdapterError{}} -> false
    end
  end

  def valid?(_call, _specification), do: false

  defp connection(%Specification{transport: :https} = specification, connection)
       when is_map(connection) do
    keys = [:url, :resolved_addresses, :connection_address, :redirect_chain, :oauth]

    with true <- exact_shape?(connection, keys),
         {:ok, origin} <- url_origin(connection[:url]),
         true <- origin in specification.discovery.redirect_origins,
         {:ok, addresses} <- public_addresses(connection[:resolved_addresses]),
         true <- connection[:connection_address] in addresses,
         true <-
           redirects?(connection[:redirect_chain], connection[:url], specification.discovery),
         {:ok, oauth, credential_reference_iri} <- oauth(connection[:oauth], specification.oauth) do
      normalized =
        connection
        |> Map.put(:resolved_addresses, addresses)
        |> Map.put(:oauth, oauth)

      {:ok, normalized, credential_reference_iri}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:mcp_runtime_connection)
    end
  end

  defp connection(%Specification{transport: :stdio} = specification, connection)
       when is_map(connection) do
    keys = [
      :sandbox_instance_iri,
      :profile_digest,
      :network,
      :separate_instance,
      :credential_mode
    ]

    with true <- exact_shape?(connection, keys),
         :ok <- Knowledge.validate_resource_identity(connection[:sandbox_instance_iri]),
         true <- connection[:profile_digest] == specification.sandbox.profile_digest,
         :deny <- connection[:network],
         true <- connection[:separate_instance],
         :brokered_reference <- connection[:credential_mode] do
      {:ok, Map.take(connection, keys), nil}
    else
      _invalid -> invalid(:mcp_runtime_sandbox)
    end
  end

  defp connection(_specification, _connection), do: invalid(:mcp_runtime_connection)

  defp oauth(runtime, accepted) when is_map(runtime) do
    keys = [
      :issuer,
      :audience,
      :scopes,
      :redirect_uri,
      :pkce_method,
      :token_passthrough,
      :credential_reference_iri
    ]

    with true <- exact_shape?(runtime, keys),
         true <- runtime[:issuer] == accepted.issuer,
         true <- runtime[:audience] == accepted.audience,
         true <- Enum.sort(runtime[:scopes]) == Enum.sort(accepted.scopes),
         true <- runtime[:redirect_uri] in accepted.redirect_uris,
         :s256 <- runtime[:pkce_method],
         false <- runtime[:token_passthrough],
         :ok <- Knowledge.validate_resource_identity(runtime[:credential_reference_iri]) do
      {:ok, Map.take(runtime, keys), runtime.credential_reference_iri}
    else
      _invalid -> invalid(:mcp_runtime_oauth)
    end
  end

  defp oauth(_runtime, _accepted), do: invalid(:mcp_runtime_oauth)

  defp redirects?(values, final_url, policy)
       when is_list(values) and values != [] and length(values) <= policy.max_redirects + 1 do
    List.first(values) == policy.discovery_url and List.last(values) == final_url and
      Enum.all?(values, fn value ->
        case url_origin(value) do
          {:ok, origin} -> origin in policy.redirect_origins
          :error -> false
        end
      end)
  end

  defp redirects?(_values, _final_url, _policy), do: false

  defp public_addresses(values) when is_list(values) and length(values) in 1..8 do
    parsed = Enum.map(values, &parse_public_address/1)

    if Enum.all?(parsed, &match?({:ok, _address}, &1)) and
         length(values) == length(Enum.uniq(values)) do
      {:ok, Enum.sort(values)}
    else
      invalid(:mcp_discovery_address)
    end
  end

  defp public_addresses(_values), do: invalid(:mcp_discovery_address)

  defp parse_public_address(value) when is_binary(value) do
    case :inet.parse_address(String.to_charlist(value)) do
      {:ok, address} -> if public_address?(address), do: {:ok, address}, else: :error
      {:error, :einval} -> :error
    end
  end

  defp parse_public_address(_value), do: :error

  defp public_address?({a, b, _c, _d}) do
    not (a in [0, 10, 127] or a >= 224 or (a == 169 and b == 254) or
           (a == 100 and b in 64..127) or (a == 172 and b in 16..31) or
           (a == 192 and b in [0, 168]) or (a == 198 and b in [18, 19]))
  end

  defp public_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: false

  defp public_address?({first, _b, _c, _d, _e, _f, _g, _h}),
    do:
      first != 0 and first not in 0xFC00..0xFDFF and first not in 0xFE80..0xFEBF and
        first not in 0xFF00..0xFFFF

  defp url_origin(value) when is_binary(value) do
    uri = URI.parse(value)

    if uri.scheme == "https" and is_binary(uri.host) and is_nil(uri.userinfo) and
         is_nil(uri.fragment) do
      port = if uri.port in [nil, 443], do: "", else: ":" <> Integer.to_string(uri.port)
      {:ok, "https://" <> String.downcase(uri.host) <> port}
    else
      :error
    end
  end

  defp url_origin(_value), do: :error

  defp validate_arguments(arguments, schema) when is_map(arguments) do
    names = Map.new(Map.keys(schema.properties), &{Atom.to_string(&1), &1})

    arguments
    |> Enum.reduce_while({:ok, %{}}, fn
      {key, value}, {:ok, normalized} when is_atom(key) ->
        if Map.has_key?(schema.properties, key) and not Map.has_key?(normalized, key),
          do: {:cont, {:ok, Map.put(normalized, key, value)}},
          else: {:halt, :error}

      {key, value}, {:ok, normalized} when is_binary(key) ->
        case Map.fetch(names, key) do
          {:ok, atom_key} when not is_map_key(normalized, atom_key) ->
            {:cont, {:ok, Map.put(normalized, atom_key, value)}}

          _unknown ->
            {:halt, :error}
        end

      _entry, _accumulator ->
        {:halt, :error}
    end)
    |> case do
      {:ok, normalized} ->
        keys = Map.keys(normalized)

        if Enum.all?(schema.required, &(&1 in keys)) and
             Enum.all?(normalized, fn {key, value} ->
               valid_type?(value, Map.fetch!(schema.properties, key))
             end) and bounded?(normalized, 32_768) do
          {:ok, normalized}
        else
          invalid(:mcp_call_arguments)
        end

      :error ->
        invalid(:mcp_call_arguments)
    end
  end

  defp validate_arguments(_arguments, _schema), do: invalid(:mcp_call_arguments)

  defp valid_type?(value, :boolean), do: is_boolean(value)

  defp valid_type?(value, :digest),
    do: is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp valid_type?(value, :resource_iri), do: Knowledge.validate_resource_identity(value) == :ok

  defp valid_type?(value, {:string, maximum}),
    do: is_binary(value) and byte_size(value) in 1..maximum and not String.contains?(value, <<0>>)

  defp valid_type?(value, {:integer, minimum, maximum}),
    do: is_integer(value) and value in minimum..maximum

  defp valid_type?(value, {:enum, values}), do: value in values

  defp valid_type?(value, {:list, type, maximum}),
    do: is_list(value) and length(value) <= maximum and Enum.all?(value, &valid_type?(&1, type))

  defp valid_type?(_value, _type), do: false

  defp secret?(%_{} = value), do: value |> Map.from_struct() |> secret?()

  defp secret?(value) when is_map(value) do
    Enum.any?(value, fn {key, item} ->
      forbidden_key?(key) or secret?(item)
    end)
  end

  defp secret?(value) when is_list(value), do: Enum.any?(value, &secret?/1)

  defp secret?(value) when is_binary(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret|authorization)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp secret?(_value), do: false

  defp forbidden_key?(key) do
    normalized = key |> to_string() |> String.downcase()
    String.contains?(normalized, ["token", "secret", "password", "authorization", "credential"])
  end

  defp exact_shape?(value, keys),
    do: MapSet.new(Map.keys(value)) == MapSet.new(keys)

  defp bounded?(value, maximum),
    do: byte_size(:erlang.term_to_binary(value, [:deterministic])) <= maximum

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
