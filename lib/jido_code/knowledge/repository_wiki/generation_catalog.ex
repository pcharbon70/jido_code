defmodule JidoCode.Knowledge.RepositoryWiki.GenerationCatalog do
  @moduledoc """
  Closed Phase 4 catalog for deterministic generation and disabled synthesis shapes.

  Repository or graph values are never resolved as modules, endpoints, credentials,
  prompts, tokenizers, prices, or fallback providers. V1 exposes only the two
  deterministic profiles as selectable profiles.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.FullCompiler
  alias JidoCode.Knowledge.RepositoryWiki.GenerationProfile
  alias JidoCode.Knowledge.RepositoryWiki.GuideRenderer
  alias JidoCode.Knowledge.RepositoryWiki.UpdateClassifier
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "wiki-generation-catalog/1.0.0"
  @deterministic_keys [:manual_deterministic, :automatic_deterministic]
  @synthesis_keys [:manual_synthesis_disabled, :automatic_synthesis_disabled]
  @synthesis_fields ~w[
    provider model region accounting_basis prompt_digest tool_policy retention_policy
    maximum_input_tokens maximum_output_tokens maximum_cached_tokens maximum_reasoning_tokens
    approved_at expires_at
  ]a

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec deterministic_keys() :: [atom()]
  def deterministic_keys, do: @deterministic_keys

  @spec synthesis_keys() :: [atom()]
  def synthesis_keys, do: @synthesis_keys

  @spec provider_adapters() :: []
  def provider_adapters, do: []

  @spec price_profiles() :: []
  def price_profiles, do: []

  @spec deterministic_profile(atom(), map()) :: {:ok, map()} | {:error, Error.t()}
  def deterministic_profile(key, attributes)
      when key in @deterministic_keys and is_map(attributes) do
    with {:ok, profile} <- GenerationProfile.new(key, attributes) do
      components = %{
        compiler: FullCompiler.profile(),
        renderer: GuideRenderer.profile(),
        classifier: UpdateClassifier.profile()
      }

      material = %{
        catalog_revision: @revision,
        profile_iri: profile.iri,
        profile_key: key,
        maintenance_mode: profile.maintenance_mode,
        generation_mode: :deterministic_only,
        preview_mode: profile.preview_mode,
        eligible?: true,
        model_calls: 0,
        token_limits: %{input: 0, output: 0, cached: 0, reasoning: 0},
        components: components,
        component_digests: Map.new(components, fn {name, value} -> {name, value.digest} end),
        limits: FullCompiler.profile().limits,
        approved_at: profile.approved_at,
        expires_at: profile.expires_at
      }

      {:ok, Map.put(material, :digest, Contract.digest(material))}
    end
  end

  def deterministic_profile(_key, _attributes), do: invalid(:wiki_generation_catalog)

  @spec disabled_synthesis_profile(atom(), map()) :: {:ok, map()} | {:error, Error.t()}
  def disabled_synthesis_profile(key, attributes)
      when key in @synthesis_keys and is_map(attributes) do
    with true <- Enum.sort(Map.keys(attributes)) == Enum.sort(@synthesis_fields),
         true <- bounded?(attributes.provider, 128),
         true <- bounded?(attributes.model, 128),
         true <- bounded?(attributes.region, 64),
         true <- bounded?(attributes.accounting_basis, 128),
         true <- Contract.digest?(attributes.prompt_digest),
         true <- attributes.tool_policy in [:none, :reviewed_read_only],
         true <- attributes.retention_policy in [:digest_only, :bounded_observation],
         true <- positive_limits?(attributes),
         true <- Contract.valid_interval?(attributes.approved_at, attributes.expires_at),
         material <- synthesis_material(key, attributes),
         digest <- Contract.digest(material),
         {:ok, iri} <- ResourceIdentity.deterministic(:wiki_generation_profile, digest) do
      {:ok, material |> Map.put(:iri, iri) |> Map.put(:digest, digest)}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_synthesis_profile)
    end
  rescue
    _error -> invalid(:wiki_synthesis_profile)
  end

  def disabled_synthesis_profile(_key, _attributes), do: invalid(:wiki_synthesis_profile)

  @spec resolve(atom(), map(), DateTime.t()) :: {:ok, map()} | {:error, Error.t()}
  def resolve(key, attributes, %DateTime{} = evaluated_at) when key in @deterministic_keys do
    with {:ok, profile} <- deterministic_profile(key, attributes),
         true <- current?(profile, evaluated_at) do
      {:ok, profile}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:unavailable, :wiki_generation_profile)}
    end
  end

  def resolve(key, _attributes, %DateTime{}) when key in @synthesis_keys,
    do: {:error, Error.new(:unavailable, :wiki_synthesis_profile)}

  def resolve(_key, _attributes, _evaluated_at), do: invalid(:wiki_generation_profile)

  defp synthesis_material(key, attributes) do
    %{
      catalog_revision: @revision,
      profile_key: key,
      maintenance_mode: if(key == :manual_synthesis_disabled, do: :manual, else: :automatic),
      generation_mode: :synthesis_allowed,
      availability: :reserved_disabled,
      enabled?: false,
      provider: attributes.provider,
      model: attributes.model,
      region: attributes.region,
      accounting_basis: attributes.accounting_basis,
      prompt_digest: attributes.prompt_digest,
      tool_policy: attributes.tool_policy,
      retention_policy: attributes.retention_policy,
      maximum_tokens: %{
        input: attributes.maximum_input_tokens,
        output: attributes.maximum_output_tokens,
        cached: attributes.maximum_cached_tokens,
        reasoning: attributes.maximum_reasoning_tokens
      },
      approved_at: DateTime.truncate(attributes.approved_at, :microsecond),
      expires_at: attributes.expires_at
    }
  end

  defp positive_limits?(attributes) do
    Enum.all?(
      ~w[maximum_input_tokens maximum_output_tokens maximum_cached_tokens maximum_reasoning_tokens]a,
      fn key -> is_integer(attributes[key]) and attributes[key] >= 0 end
    ) and attributes.maximum_input_tokens > 0 and attributes.maximum_output_tokens > 0
  end

  defp current?(profile, evaluated_at) do
    DateTime.compare(profile.approved_at, evaluated_at) in [:lt, :eq] and
      (is_nil(profile.expires_at) or DateTime.compare(evaluated_at, profile.expires_at) == :lt)
  end

  defp bounded?(value, maximum),
    do: is_binary(value) and byte_size(value) in 1..maximum and String.valid?(value)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
