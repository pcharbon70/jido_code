defmodule JidoCode.Factory.Egress.Destination do
  @moduledoc "Closed HTTPS destination admitted by one egress policy."

  alias JidoCode.Factory.AdapterError

  @derive {Inspect, only: [:scheme, :host, :port, :path_prefix, :kind]}
  @enforce_keys [:scheme, :host, :port, :path_prefix, :kind]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @kinds [:approved_api, :controlled_mirror]

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with "https" <- attributes[:scheme],
         :ok <- hostname(attributes[:host]),
         port when is_integer(port) and port in 1..65_535 <- attributes[:port],
         :ok <- path_prefix(attributes[:path_prefix]),
         kind when kind in @kinds <- attributes[:kind] do
      {:ok,
       %__MODULE__{
         scheme: "https",
         host: attributes.host,
         port: port,
         path_prefix: attributes.path_prefix,
         kind: kind
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec matches?(t(), URI.t()) :: boolean()
  def matches?(%__MODULE__{} = destination, %URI{} = uri) do
    destination.scheme == uri.scheme and destination.host == uri.host and
      destination.port == (uri.port || 443) and path_matches?(destination.path_prefix, uri.path)
  end

  defp path_matches?("/", path), do: is_binary(path) and String.starts_with?(path, "/")

  defp path_matches?(prefix, path) when is_binary(path) do
    path == prefix or String.starts_with?(path, prefix <> "/")
  end

  defp path_matches?(_prefix, _path), do: false

  defp hostname(value) when is_binary(value) do
    labels = String.split(value, ".")

    valid? =
      byte_size(value) in 1..253 and value == String.downcase(value) and length(labels) >= 2 and
        Enum.all?(labels, fn label ->
          byte_size(label) in 1..63 and Regex.match?(~r/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/, label)
        end)

    if valid?, do: :ok, else: :error
  end

  defp hostname(_value), do: :error

  defp path_prefix(value) when is_binary(value) do
    segments = String.split(value, "/", trim: true)

    if byte_size(value) in 1..512 and String.starts_with?(value, "/") and
         not String.contains?(value, ["\\", "%", "?", "#"]) and
         not Enum.any?(segments, &(&1 in [".", ".."])) and
         (value == "/" or not String.ends_with?(value, "/")),
       do: :ok,
       else: :error
  end

  defp path_prefix(_value), do: :error
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :egress_destination)}
end
