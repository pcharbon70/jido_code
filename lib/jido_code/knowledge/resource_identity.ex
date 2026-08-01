defmodule JidoCode.Knowledge.ResourceIdentity do
  @moduledoc """
  Pure construction and validation of canonical product resource IRIs.

  Natural external identities are normalized before construction. Local
  identities use a caller-supplied millisecond timestamp and ten entropy bytes;
  `generate_local/2` is the explicit clock/random port for runtime callers.
  """

  alias JidoCode.Knowledge.Error

  @base "https://jido.run/id/"
  @max_iri_bytes 512
  @max_segment_bytes 160
  @local_kinds ~w[
    activity audit claim command decision delegation goal attempt migration transition
    validation-report validation-result
  ]
  @deterministic_kinds ~w[
    authorization-grant change-set command-request graph-revision-reference validation-report
    validation-result
  ]
  @digest_lengths %{"sha1" => 40, "sha256" => 64, "sha512" => 128}
  @max_timestamp 281_474_976_710_655

  @spec base() :: String.t()
  def base, do: @base

  @spec provider_host(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def provider_host(input) when is_binary(input) do
    with {:ok, host} <- normalize_host(input),
         {:ok, segment} <- encode_segment(host) do
      build("provider", [segment])
    end
  end

  def provider_host(_input), do: invalid(:provider_identity)

  @spec repository(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def repository(external_identity) when is_binary(external_identity) do
    with {:ok, normalized} <- normalize_text(external_identity, @max_segment_bytes) do
      build("repository", [digest_token("repository", normalized)])
    end
  end

  def repository(_external_identity), do: invalid(:repository_identity)

  @spec repository_locator(String.t(), String.t(), String.t()) ::
          {:ok, %{canonical: String.t(), iri: String.t()}} | {:error, Error.t()}
  def repository_locator(provider, owner, name)
      when is_binary(provider) and is_binary(owner) and is_binary(name) do
    with {:ok, host} <- normalize_host(provider),
         {:ok, canonical_owner} <- normalize_text(owner, @max_segment_bytes),
         {:ok, canonical_name} <- normalize_repository_name(name),
         {:ok, host_segment} <- encode_segment(host),
         {:ok, owner_segment} <- encode_segment(canonical_owner),
         {:ok, name_segment} <- encode_segment(canonical_name),
         {:ok, iri} <- build("repository-locator", [host_segment, owner_segment, name_segment]) do
      {:ok, %{iri: iri, canonical: "#{host}/#{canonical_owner}/#{canonical_name}"}}
    end
  end

  def repository_locator(_provider, _owner, _name), do: invalid(:repository_locator)

  @spec git_object(String.t() | atom(), String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def git_object(algorithm, hex) when is_binary(hex) do
    with {:ok, normalized_algorithm} <- normalize_algorithm(algorithm, ["sha1", "sha256"]),
         {:ok, normalized_hex} <- normalize_hex(hex, @digest_lengths[normalized_algorithm]) do
      build("git-object", [normalized_algorithm, normalized_hex])
    end
  end

  def git_object(_algorithm, _hex), do: invalid(:git_object_identity)

  @spec content_digest(String.t() | atom(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def content_digest(algorithm, hex) when is_binary(hex) do
    with {:ok, normalized_algorithm} <- normalize_algorithm(algorithm, ["sha256", "sha512"]),
         {:ok, normalized_hex} <- normalize_hex(hex, @digest_lengths[normalized_algorithm]) do
      build("content", [normalized_algorithm, normalized_hex])
    end
  end

  def content_digest(_algorithm, _hex), do: invalid(:content_identity)

  @spec scope(String.t() | atom(), String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def scope(kind, value) when is_binary(value) do
    with {:ok, kind_segment} <-
           known_kind(kind, ~w[factory organization cohort repository branch path package symbol]),
         {:ok, normalized} <- normalize_text(value, @max_segment_bytes),
         {:ok, value_segment} <- encode_segment(normalized) do
      build("scope", [kind_segment, value_segment])
    end
  end

  def scope(_kind, _value), do: invalid(:scope_identity)

  @spec local(String.t() | atom(), non_neg_integer(), binary()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def local(kind, timestamp_ms, entropy)
      when is_integer(timestamp_ms) and timestamp_ms >= 0 and timestamp_ms <= @max_timestamp and
             is_binary(entropy) and byte_size(entropy) == 10 do
    with {:ok, kind_segment} <- known_kind(kind, @local_kinds) do
      timestamp = timestamp_ms |> :binary.encode_unsigned() |> left_pad(6)
      token = Base.encode16(timestamp <> entropy, case: :lower)
      build(kind_segment, [token])
    end
  end

  def local(_kind, _timestamp_ms, _entropy), do: invalid(:local_identity)

  @spec generate_local(String.t() | atom(), keyword()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def generate_local(kind, options \\ []) do
    clock = Keyword.get(options, :clock, fn -> System.system_time(:millisecond) end)
    random = Keyword.get(options, :random, &:crypto.strong_rand_bytes/1)

    local(kind, clock.(), random.(10))
  rescue
    _error -> invalid(:local_identity)
  catch
    _kind, _reason -> invalid(:local_identity)
  end

  @spec deterministic(String.t() | atom(), String.t()) ::
          {:ok, String.t()} | {:error, Error.t()}
  def deterministic(kind, material) when is_binary(material) do
    with {:ok, kind_segment} <- known_kind(kind, @deterministic_kinds) do
      build(kind_segment, [digest_token(kind_segment, material)])
    end
  end

  def deterministic(_kind, _material), do: invalid(:deterministic_identity)

  @spec validate(term()) :: :ok | {:error, Error.t()}
  def validate(%RDF.IRI{value: value}), do: validate(value)

  def validate(value) when is_binary(value) do
    normalized = :unicode.characters_to_nfc_binary(value)

    if value == normalized and String.starts_with?(value, @base) and
         byte_size(value) <= @max_iri_bytes and RDF.IRI.valid?(value) and
         not control_character?(value) and not String.contains?(value, ["/../", "/./"]) do
      :ok
    else
      invalid(:resource_identity)
    end
  rescue
    _error -> invalid(:resource_identity)
  end

  def validate(_value), do: invalid(:resource_identity)

  @spec validate_relationship(term()) :: :ok | {:error, Error.t()}
  def validate_relationship({subject, predicate, object}) do
    with :ok <- validate(subject),
         true <- iri?(predicate),
         :ok <- validate(object) do
      :ok
    else
      _invalid -> invalid(:resource_relationship)
    end
  end

  def validate_relationship(_relationship), do: invalid(:resource_relationship)

  @spec graph_token(String.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def graph_token(resource_iri) do
    with :ok <- validate(resource_iri) do
      {:ok, digest_token("graph-scope", resource_iri)}
    end
  end

  defp normalize_host(input) do
    with {:ok, normalized} <- normalize_text(input, @max_segment_bytes),
         uri <- parse_host_uri(normalized),
         true <- valid_host_uri?(uri),
         host when is_binary(host) <- uri.host,
         canonical_host <- host |> String.downcase() |> String.trim_trailing("."),
         true <- valid_ascii_host?(canonical_host) do
      {:ok, canonical_host_with_port(canonical_host, uri)}
    else
      _invalid -> invalid(:provider_identity)
    end
  end

  defp parse_host_uri(input) do
    if String.contains?(input, "://"), do: URI.parse(input), else: URI.parse("https://" <> input)
  end

  defp valid_host_uri?(uri) do
    uri.scheme in ["http", "https"] and is_nil(uri.userinfo) and
      uri.path in [nil, "", "/"] and is_nil(uri.query) and is_nil(uri.fragment)
  end

  defp valid_ascii_host?(host) do
    byte_size(host) in 1..253 and
      Regex.match?(
        ~r/^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)(?:\.(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?))*$/,
        host
      )
  end

  defp canonical_host_with_port(host, %{port: nil}), do: host
  defp canonical_host_with_port(host, %{scheme: "https", port: 443}), do: host
  defp canonical_host_with_port(host, %{scheme: "http", port: 80}), do: host
  defp canonical_host_with_port(host, %{port: port}) when port in 1..65_535, do: "#{host}:#{port}"
  defp canonical_host_with_port(_host, _uri), do: nil

  defp normalize_repository_name(name) do
    name
    |> String.trim()
    |> String.trim_trailing(".git")
    |> normalize_text(@max_segment_bytes)
  end

  defp normalize_text(value, max_bytes) do
    normalized = value |> String.trim() |> :unicode.characters_to_nfc_binary()

    if normalized != "" and byte_size(normalized) <= max_bytes and
         not control_character?(normalized) and normalized not in [".", ".."] and
         not traversal_segment?(normalized) do
      {:ok, normalized}
    else
      invalid(:identity_segment)
    end
  rescue
    _error -> invalid(:identity_segment)
  end

  defp encode_segment(value) do
    {:ok, URI.encode(value, &URI.char_unreserved?/1)}
  rescue
    _error -> invalid(:identity_segment)
  end

  defp normalize_algorithm(algorithm, allowed) do
    value = if is_atom(algorithm), do: Atom.to_string(algorithm), else: algorithm

    if value in allowed, do: {:ok, value}, else: invalid(:digest_algorithm)
  end

  defp normalize_hex(hex, expected_length) do
    normalized = String.downcase(hex)

    if byte_size(normalized) == expected_length and Regex.match?(~r/^[a-f0-9]+$/, normalized) do
      {:ok, normalized}
    else
      invalid(:digest_value)
    end
  end

  defp known_kind(kind, allowed) do
    value = if is_atom(kind), do: kind |> Atom.to_string() |> String.replace("_", "-"), else: kind

    if value in allowed, do: {:ok, value}, else: invalid(:identity_kind)
  end

  defp build(kind, segments) do
    iri = @base <> Enum.join([kind | segments], "/")

    case validate(iri) do
      :ok -> {:ok, iri}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp digest_token(kind, value) do
    :crypto.hash(:sha256, kind <> "\n" <> value)
    |> Base.encode16(case: :lower)
    |> binary_part(0, 32)
  end

  defp left_pad(binary, size) do
    :binary.copy(<<0>>, size - byte_size(binary)) <> binary
  end

  defp iri?(%RDF.IRI{} = iri), do: RDF.IRI.valid?(iri)
  defp iri?(value) when is_binary(value), do: RDF.IRI.valid?(value)
  defp iri?(_value), do: false

  defp control_character?(value), do: Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp traversal_segment?(value),
    do: value |> String.split(["/", "\\"]) |> Enum.any?(&(&1 in [".", ".."]))

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
