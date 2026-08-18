defmodule JidoCode.Factory.Extensions.MCP.Specification do
  @moduledoc """
  Accepted, digest-bound onboarding contract for one MCP server.

  Discovery documents, descriptors, annotations, and remote schemas are never
  authority. This contract contains the separately reviewed local schemas and
  the exact remote digests they were reviewed against.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge

  @contract_version "1.0.0"
  @keys [
    :revision,
    :status,
    :specification_iri,
    :evidence_iri,
    :protocol_version,
    :server_package,
    :server_package_digest,
    :server_identity,
    :transport,
    :adapter_identity,
    :adapter_digest,
    :descriptor_digest,
    :discovery,
    :oauth,
    :sandbox,
    :tools
  ]
  @tool_keys [
    :name,
    :namespaced_name,
    :descriptor_digest,
    :input_schema,
    :input_schema_digest,
    :output_schema,
    :output_schema_digest,
    :max_output_bytes,
    :approval_required,
    :phase3_tool
  ]
  @schema_keys [:additional_properties, :required, :properties]

  @enforce_keys @keys ++ [:digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- exact_shape?(attributes, @keys),
         revision when is_binary(revision) and byte_size(revision) in 1..128 <-
           attributes[:revision],
         :accepted <- attributes[:status],
         :ok <- resources(attributes, [:specification_iri, :evidence_iri]),
         true <- text?(attributes[:protocol_version], 64),
         true <- text?(attributes[:server_package], 256),
         true <- digest?(attributes[:server_package_digest]),
         identity when is_binary(identity) <- attributes[:server_identity],
         true <- Regex.match?(~r/^[a-z][a-z0-9-]{0,63}$/, identity),
         transport when transport in [:https, :stdio] <- attributes[:transport],
         true <- text?(attributes[:adapter_identity], 256),
         true <- digest?(attributes[:adapter_digest]),
         true <- attributes.adapter_digest == Definition.digest(attributes.adapter_identity),
         true <- digest?(attributes[:descriptor_digest]),
         :ok <- connection_policy(transport, attributes),
         {:ok, tools} <- tools(attributes[:tools], identity),
         normalized <- attributes |> Map.put(:tools, tools),
         digest <- digest(Map.take(normalized, @keys)) do
      {:ok, struct!(__MODULE__, Map.put(normalized, :digest, digest))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:mcp_specification)
    end
  rescue
    _error -> invalid(:mcp_specification)
  end

  def new(_attributes), do: invalid(:mcp_specification)

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = specification) do
    attributes = specification |> Map.from_struct() |> Map.take(@keys)

    case new(attributes) do
      {:ok, rebuilt} -> rebuilt == specification
      {:error, %AdapterError{}} -> false
    end
  end

  def valid?(_specification), do: false

  @spec fetch_tool(t(), String.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def fetch_tool(%__MODULE__{} = specification, namespaced_name)
      when is_binary(namespaced_name) do
    with true <- valid?(specification),
         tool when is_map(tool) <-
           Enum.find(specification.tools, &(&1.namespaced_name == namespaced_name)) do
      {:ok, tool}
    else
      _invalid -> invalid(:mcp_tool_specification)
    end
  end

  def fetch_tool(_specification, _namespaced_name), do: invalid(:mcp_tool_specification)

  @spec digest(term()) :: String.t()
  def digest(value), do: Definition.digest(value)

  defp connection_policy(:https, attributes) do
    with :ok <- discovery(attributes[:discovery]),
         :ok <- oauth(attributes[:oauth]),
         :not_applicable <- attributes[:sandbox] do
      :ok
    else
      _invalid -> invalid(:mcp_connection_policy)
    end
  end

  defp connection_policy(:stdio, attributes) do
    with :not_applicable <- attributes[:discovery],
         :not_applicable <- attributes[:oauth],
         :ok <- sandbox(attributes[:sandbox]) do
      :ok
    else
      _invalid -> invalid(:mcp_connection_policy)
    end
  end

  defp discovery(policy) when is_map(policy) do
    keys = [
      :origin,
      :discovery_url,
      :redirect_origins,
      :max_redirects,
      :reject_private_addresses,
      :pin_connection_address
    ]

    with true <- exact_shape?(policy, keys),
         {:ok, origin} <- public_origin(policy[:origin]),
         {:ok, discovery_origin} <- public_url_origin(policy[:discovery_url]),
         true <- origin == discovery_origin,
         true <- origins?(policy[:redirect_origins]),
         true <- origin in policy.redirect_origins,
         maximum when is_integer(maximum) and maximum in 0..5 <- policy[:max_redirects],
         true <- policy[:reject_private_addresses],
         true <- policy[:pin_connection_address] do
      :ok
    else
      _invalid -> invalid(:mcp_discovery_policy)
    end
  end

  defp discovery(_policy), do: invalid(:mcp_discovery_policy)

  defp oauth(policy) when is_map(policy) do
    keys = [
      :issuer,
      :audience,
      :scopes,
      :redirect_uris,
      :pkce_method,
      :token_passthrough
    ]

    with true <- exact_shape?(policy, keys),
         {:ok, _issuer_origin} <- public_url_origin(policy[:issuer]),
         true <- text?(policy[:audience], 256),
         true <- text_list?(policy[:scopes], 32, 128, false),
         true <- public_urls?(policy[:redirect_uris], 8),
         :s256 <- policy[:pkce_method],
         false <- policy[:token_passthrough] do
      :ok
    else
      _invalid -> invalid(:mcp_oauth_policy)
    end
  end

  defp oauth(_policy), do: invalid(:mcp_oauth_policy)

  defp sandbox(policy) when is_map(policy) do
    keys = [:profile_digest, :network, :separate_instance, :credential_mode]

    with true <- exact_shape?(policy, keys),
         true <- digest?(policy[:profile_digest]),
         :deny <- policy[:network],
         true <- policy[:separate_instance],
         :brokered_reference <- policy[:credential_mode] do
      :ok
    else
      _invalid -> invalid(:mcp_sandbox_policy)
    end
  end

  defp sandbox(_policy), do: invalid(:mcp_sandbox_policy)

  defp tools(values, identity) when is_list(values) and length(values) in 1..64 do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, accepted} ->
      case tool(value, identity) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | accepted]}}
        {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, accepted} ->
        accepted = Enum.sort_by(accepted, & &1.namespaced_name)
        names = Enum.map(accepted, & &1.namespaced_name)

        if length(names) == length(Enum.uniq(names)),
          do: {:ok, accepted},
          else: invalid(:mcp_tool_specification)

      {:error, %AdapterError{} = error} ->
        {:error, error}
    end
  end

  defp tools(_values, _identity), do: invalid(:mcp_tool_specification)

  defp tool(value, identity) when is_map(value) do
    with true <- exact_shape?(value, @tool_keys),
         name when is_binary(name) <- value[:name],
         true <- Regex.match?(~r/^[a-z][a-z0-9_-]{0,63}$/, name),
         true <- value[:namespaced_name] == identity <> "/" <> name,
         true <- digest?(value[:descriptor_digest]),
         :ok <- schema(value[:input_schema]),
         :ok <- schema(value[:output_schema]),
         true <- digest?(value[:input_schema_digest]),
         true <- digest?(value[:output_schema_digest]),
         true <- value.input_schema_digest == digest(value.input_schema),
         true <- value.output_schema_digest == digest(value.output_schema),
         maximum when is_integer(maximum) and maximum in 1..131_072 <-
           value[:max_output_bytes],
         true <- value[:approval_required],
         "run_governed_command" <- value[:phase3_tool] do
      {:ok, Map.take(value, @tool_keys)}
    else
      _invalid -> invalid(:mcp_tool_specification)
    end
  end

  defp tool(_value, _identity), do: invalid(:mcp_tool_specification)

  defp schema(value) when is_map(value) do
    with true <- exact_shape?(value, @schema_keys),
         false <- value[:additional_properties],
         required when is_list(required) <- value[:required],
         properties when is_map(properties) and map_size(properties) in 1..64 <-
           value[:properties],
         true <- Enum.all?(Map.keys(properties), &is_atom/1),
         true <- Enum.all?(required, &is_atom/1),
         true <- length(required) == length(Enum.uniq(required)),
         true <- Enum.all?(required, &Map.has_key?(properties, &1)),
         true <- Enum.all?(properties, fn {_key, type} -> schema_type?(type) end),
         true <- bounded?(value, 16_384) do
      :ok
    else
      _invalid -> invalid(:mcp_closed_schema)
    end
  end

  defp schema(_value), do: invalid(:mcp_closed_schema)

  defp schema_type?(:boolean), do: true
  defp schema_type?(:digest), do: true
  defp schema_type?(:resource_iri), do: true

  defp schema_type?({:string, maximum}),
    do: is_integer(maximum) and maximum in 1..32_768

  defp schema_type?({:integer, minimum, maximum}),
    do: is_integer(minimum) and is_integer(maximum) and minimum <= maximum

  defp schema_type?({:enum, values}),
    do:
      is_list(values) and values != [] and length(values) <= 64 and
        Enum.all?(values, &(is_binary(&1) or is_atom(&1) or is_integer(&1))) and
        length(values) == length(Enum.uniq(values))

  defp schema_type?({:list, type, maximum}),
    do: is_integer(maximum) and maximum in 1..128 and schema_type?(type)

  defp schema_type?(_type), do: false

  defp public_origin(value) when is_binary(value) do
    uri = URI.parse(value)

    if uri.scheme == "https" and public_host?(uri.host) and is_nil(uri.userinfo) and
         uri.path in [nil, ""] and is_nil(uri.query) and is_nil(uri.fragment) do
      {:ok, origin(uri)}
    else
      :error
    end
  end

  defp public_origin(_value), do: :error

  defp public_url_origin(value) when is_binary(value) do
    uri = URI.parse(value)

    if uri.scheme == "https" and public_host?(uri.host) and is_nil(uri.userinfo) and
         is_nil(uri.fragment) do
      {:ok, origin(uri)}
    else
      :error
    end
  end

  defp public_url_origin(_value), do: :error

  defp public_host?(host) when is_binary(host) do
    normalized = String.downcase(host)

    normalized not in ["localhost", "localhost.localdomain"] and
      not String.ends_with?(normalized, [".local", ".internal", ".localhost"]) and
      not private_literal?(normalized)
  end

  defp public_host?(_host), do: false

  defp private_literal?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, address} -> private_address?(address)
      {:error, :einval} -> false
    end
  end

  defp private_address?({a, b, _c, _d}) do
    a in [0, 10, 127] or a >= 224 or (a == 169 and b == 254) or
      (a == 100 and b in 64..127) or (a == 172 and b in 16..31) or
      (a == 192 and b in [0, 168]) or (a == 198 and b in [18, 19])
  end

  defp private_address?({0, 0, 0, 0, 0, 0, 0, 1}), do: true

  defp private_address?({first, _b, _c, _d, _e, _f, _g, _h}),
    do:
      first == 0 or first in 0xFC00..0xFDFF or first in 0xFE80..0xFEBF or
        first in 0xFF00..0xFFFF

  defp origin(%URI{scheme: scheme, host: host, port: nil}), do: scheme <> "://" <> host

  defp origin(%URI{scheme: scheme, host: host, port: 443}), do: scheme <> "://" <> host

  defp origin(%URI{scheme: scheme, host: host, port: port}),
    do: scheme <> "://" <> host <> ":" <> Integer.to_string(port)

  defp origins?(values),
    do:
      is_list(values) and values != [] and length(values) <= 8 and
        Enum.all?(values, &match?({:ok, _origin}, public_origin(&1))) and
        length(values) == length(Enum.uniq(values))

  defp public_urls?(values, maximum),
    do:
      is_list(values) and values != [] and length(values) <= maximum and
        Enum.all?(values, &match?({:ok, _origin}, public_url_origin(&1))) and
        length(values) == length(Enum.uniq(values))

  defp resources(attributes, keys) do
    if Enum.all?(keys, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid(:mcp_specification_evidence)
  end

  defp exact_shape?(value, keys),
    do: MapSet.new(Map.keys(value)) == MapSet.new(keys)

  defp digest?(value),
    do: is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp text?(value, maximum),
    do:
      is_binary(value) and byte_size(value) in 1..maximum and
        not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text_list?(values, count, maximum, empty?)
       when is_list(values) and length(values) <= count do
    (empty? or values != []) and Enum.all?(values, &text?(&1, maximum)) and
      length(values) == length(Enum.uniq(values))
  end

  defp text_list?(_values, _count, _maximum, _empty?), do: false

  defp bounded?(value, maximum),
    do: byte_size(:erlang.term_to_binary(value, [:deterministic])) <= maximum

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
