defmodule JidoCode.Knowledge.RepositoryWiki.DependencyLinks do
  @moduledoc "Deterministic safe-link policy for dependency wiki pages."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.ResourceIdentity

  @profile "wiki-dependency-links/1.0.0"
  @maximums %{links: 40, url_bytes: 2_048, label_bytes: 128}
  @package ~r/^[a-z][a-z0-9_]{0,127}$/
  @version ~r/^[0-9A-Za-z][0-9A-Za-z.+_-]{0,127}$/

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      limits: @maximums,
      schemes: ["https"],
      ports: [443],
      IP_literals: :deny,
      credentials: :deny,
      unicode_hostnames: :deny,
      internal_navigation: :deny,
      redirects: :not_followed,
      unsafe_values: :text_only
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec build(map(), map() | nil, map()) :: {:ok, map()} | {:error, Error.t()}
  def build(node, metadata, attributes)
      when is_map(node) and (is_map(metadata) or is_nil(metadata)) and is_map(attributes) do
    with :ok <- validate(node, metadata, attributes),
         candidates <- generated_candidates(node) ++ metadata_candidates(metadata),
         true <- length(candidates) <= @maximums.links,
         {:ok, links} <- links(candidates, node, metadata, attributes) do
      result = %{
        profile: @profile,
        profile_digest: profile().digest,
        dependency_iri: node.iri,
        links: links,
        clickable_count: Enum.count(links, &(&1.verification == :verified)),
        text_only_count: Enum.count(links, &(&1.verification == :text_only)),
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      {:ok, Map.put(result, :digest, Contract.digest(result))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def build(_node, _metadata, _attributes), do: invalid()

  defp validate(node, metadata, attributes) do
    cond do
      ResourceIdentity.validate(node[:iri]) != :ok or
          ResourceIdentity.validate(attributes[:edition_iri]) != :ok ->
        invalid()

      not is_binary(node[:name]) or byte_size(node.name) > 128 ->
        invalid()

      metadata &&
          (metadata[:profile] != "hex-req/1.0.0" or not Contract.digest?(metadata[:digest]) or
             Contract.digest(Map.delete(metadata, :digest)) != metadata.digest or
             metadata[:package] != package_name(node) or
             metadata[:version] != node[:selected_version]) ->
        invalid()

      true ->
        :ok
    end
  end

  defp generated_candidates(node) do
    hex = hex_candidates(node)

    source =
      case node[:source] do
        %{state: :verified, external_link_eligible: true, canonical_url: url} ->
          [%{kind: :source, label: "Source", value: url, origin: :verified_source}]

        _unverified ->
          []
      end

    hex ++ source
  end

  defp hex_candidates(%{scm: "hex", selected_version: version} = node)
       when is_binary(version) do
    package = package_name(node)

    if Regex.match?(@package, package) and Regex.match?(@version, version) and
         get_in(node, [:lock, :repository]) == "hexpm" do
      [
        %{
          kind: :package,
          label: "Hex package",
          value: "https://hex.pm/packages/#{package}",
          origin: :verified_lock
        },
        %{
          kind: :release,
          label: "Hex release #{version}",
          value: "https://hex.pm/packages/#{package}/#{version}",
          origin: :verified_lock
        },
        %{
          kind: :documentation,
          label: "HexDocs #{version}",
          value: "https://hexdocs.pm/#{package}/#{version}",
          origin: :verified_lock
        }
      ]
    else
      []
    end
  end

  defp hex_candidates(_node), do: []

  defp metadata_candidates(nil), do: []

  defp metadata_candidates(metadata) do
    metadata
    |> get_in([:facts, :links])
    |> case do
      values when is_list(values) ->
        Enum.map(values, fn value ->
          %{
            kind: link_kind(value.label),
            label: value.label,
            value: value.value,
            origin: :observed_hex_metadata
          }
        end)

      _missing ->
        []
    end
  end

  defp links(candidates, node, metadata, attributes) do
    retrieved_at = if(metadata, do: metadata[:retrieved_at], else: nil)

    candidates
    |> Enum.uniq_by(&{&1.kind, &1.value})
    |> Enum.sort_by(&{to_string(&1.kind), &1.label, &1.value})
    |> Enum.reduce_while({:ok, []}, fn candidate, {:ok, result} ->
      record = link_record(candidate, retrieved_at, node, metadata, attributes)

      case ResourceIdentity.deterministic(
             :wiki_link,
             Enum.join(
               [
                 attributes.edition_iri,
                 node.iri,
                 to_string(candidate.kind),
                 Contract.digest(record)
               ],
               "\n"
             )
           ) do
        {:ok, iri} -> {:cont, {:ok, [Map.put(record, :iri, iri) | result]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp link_record(candidate, retrieved_at, node, metadata, attributes) do
    case safe_external_url(candidate.value) do
      {:ok, canonical} ->
        %{
          kind: candidate.kind,
          label: safe_label(candidate.label),
          destination: canonical,
          display: canonical,
          origin: candidate.origin,
          verification: :verified,
          navigation: :external_noopener_noreferrer_nofollow,
          retrieved_at: retrieved_at,
          provenance: %{
            dependency_iri: node.iri,
            edition_iri: attributes.edition_iri,
            metadata_digest: metadata_digest(candidate, metadata)
          }
        }

      {:error, reason} ->
        %{
          kind: candidate.kind,
          label: safe_label(candidate.label),
          destination: nil,
          display: safe_display(candidate.value),
          origin: candidate.origin,
          verification: :text_only,
          reason: reason,
          navigation: :none,
          retrieved_at: retrieved_at,
          provenance: %{
            dependency_iri: node.iri,
            edition_iri: attributes.edition_iri,
            metadata_digest: metadata_digest(candidate, metadata)
          }
        }
    end
  end

  defp safe_external_url(value)
       when is_binary(value) and byte_size(value) in 1..@maximums.url_bytes//1 do
    downcased = String.downcase(value)
    uri = URI.parse(value)
    host = uri.host && String.downcase(uri.host)

    authority =
      value |> String.replace_prefix("https://", "") |> String.split("/", parts: 2) |> hd()

    cond do
      not ascii_visible?(value) or String.normalize(value, :nfc) != value ->
        {:error, :unsafe_characters}

      uri.scheme != "https" or is_nil(host) or host == "" ->
        {:error, :unsafe_scheme}

      uri.userinfo || String.contains?(String.downcase(authority), ["@", "%40"]) ->
        {:error, :credentials}

      uri.port not in [nil, 443] ->
        {:error, :unsafe_port}

      uri.path && String.starts_with?(uri.path, "//") ->
        {:error, :ambiguous_path}

      String.contains?(downcased, ["%00", "%0a", "%0d", "\\"]) ->
        {:error, :encoded_control}

      not valid_public_host?(host) ->
        {:error, :private_or_ambiguous_host}

      true ->
        {:ok, URI.to_string(%{uri | host: host})}
    end
  rescue
    _error -> {:error, :invalid_url}
  end

  defp safe_external_url(_value), do: {:error, :invalid_url}

  defp valid_public_host?(host) do
    ascii_visible?(host) and host == String.downcase(host) and not String.ends_with?(host, ".") and
      Regex.match?(~r/^[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?$/, host) and
      not internal_host?(host) and not ip_literal?(host)
  end

  defp internal_host?(host) do
    host in ["localhost", "jido.run"] or
      Enum.any?([".localhost", ".local", ".internal", ".jido.run"], &String.ends_with?(host, &1))
  end

  defp ip_literal?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, _address} -> true
      {:error, :einval} -> false
    end
  end

  defp ascii_visible?(value),
    do: value |> :binary.bin_to_list() |> Enum.all?(&(&1 >= 32 and &1 <= 126))

  defp safe_label(value) do
    case safe_display(value) do
      nil -> "External reference"
      label -> String.slice(label, 0, @maximums.label_bytes)
    end
  end

  defp safe_display(value) when is_binary(value) do
    value
    |> :binary.bin_to_list()
    |> Enum.filter(&(&1 >= 32 and &1 <= 126))
    |> List.to_string()
    |> String.slice(0, @maximums.url_bytes)
  end

  defp safe_display(_value), do: nil

  defp link_kind(label) do
    normalized = label |> to_string() |> String.downcase()

    cond do
      String.contains?(normalized, ["source", "github", "gitlab"]) -> :source
      String.contains?(normalized, "home") -> :homepage
      String.contains?(normalized, "change") -> :changelog
      String.contains?(normalized, "license") -> :license
      true -> :external_reference
    end
  end

  defp metadata_digest(%{origin: :observed_hex_metadata}, metadata),
    do: metadata[:digest]

  defp metadata_digest(_candidate, _node), do: nil

  defp package_name(node), do: get_in(node, [:lock, :package]) || node.name
  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_dependency_links)}
end
