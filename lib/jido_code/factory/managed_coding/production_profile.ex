defmodule JidoCode.Factory.ManagedCoding.ProductionProfile do
  @moduledoc "Signed, content-addressed production profile and supported operating envelope."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Budget
  alias JidoCode.Factory.ManagedCoding.Identity

  @components ~w[provider_model prompt_templates context_policy tool_registry model_adapter tool_adapter sandbox_image check_registry credential_policy memory_mode verifier_environment]a
  @envelope_keys ~w[repository_classes task_classes languages dependency_policies network_modes actor_requirements exclusion_rules unavailable_capabilities]a
  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys ~w[profile_iri revision components budget check_limit retry_limit envelope state rollout_stage approved_at expires_at signer_iri profile_digest signed_digest]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- Identity.validate_resource(attributes[:profile_iri]),
         revision when is_integer(revision) and revision > 0 <- attributes[:revision],
         :ok <- components(attributes[:components]),
         %Budget{} <- attributes[:budget],
         check_limit when is_integer(check_limit) and check_limit > 0 <- attributes[:check_limit],
         retry_limit when is_integer(retry_limit) and retry_limit >= 0 <- attributes[:retry_limit],
         :ok <- envelope(attributes[:envelope]),
         :approved <- attributes[:state],
         stage when stage in [:evaluation, :shadow, :pilot, :production] <-
           attributes[:rollout_stage],
         %DateTime{} = approved_at <- attributes[:approved_at],
         %DateTime{} = expires_at <- attributes[:expires_at],
         true <- DateTime.before?(approved_at, expires_at),
         :ok <- Identity.validate_resource(attributes[:signer_iri]) do
      material =
        Map.take(attributes, [
          :profile_iri,
          :revision,
          :components,
          :budget,
          :check_limit,
          :retry_limit,
          :envelope,
          :state,
          :rollout_stage,
          :approved_at,
          :expires_at,
          :signer_iri
        ])

      profile_digest = digest(material)

      if attributes[:signed_digest] == profile_digest do
        {:ok,
         struct!(
           __MODULE__,
           material
           |> Map.put(:profile_digest, profile_digest)
           |> Map.put(:signed_digest, attributes.signed_digest)
         )}
      else
        invalid()
      end
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec material_digest(map()) :: String.t()
  def material_digest(attributes) when is_map(attributes) do
    attributes
    |> Map.take([
      :profile_iri,
      :revision,
      :components,
      :budget,
      :check_limit,
      :retry_limit,
      :envelope,
      :state,
      :rollout_stage,
      :approved_at,
      :expires_at,
      :signer_iri
    ])
    |> digest()
  end

  @spec compatible?(t(), map(), DateTime.t()) :: boolean()
  def compatible?(%__MODULE__{} = profile, inventory, %DateTime{} = now) when is_map(inventory) do
    profile.state == :approved and DateTime.before?(now, profile.expires_at) and
      inventory[:approved_profile_digest] == profile.profile_digest and
      Enum.all?(@components, fn component ->
        inventory[component] == profile.components[component]
      end)
  end

  def compatible?(_profile, _inventory, _now), do: false

  @spec admits?(t(), map()) :: boolean()
  def admits?(%__MODULE__{} = profile, request) when is_map(request) do
    envelope = profile.envelope

    request[:repository_class] in envelope.repository_classes and
      request[:task_class] in envelope.task_classes and request[:language] in envelope.languages and
      request[:dependency_policy] in envelope.dependency_policies and
      request[:network_mode] in envelope.network_modes and
      Enum.all?(envelope.actor_requirements, &(&1 in request[:actor_attributes])) and
      Enum.all?(request[:requested_capabilities], &(&1 not in envelope.unavailable_capabilities)) and
      Enum.all?(envelope.exclusion_rules, &(not excluded?(request, &1)))
  end

  def admits?(_profile, _request), do: false

  @spec components() :: [atom()]
  def components, do: @components

  defp components(values) when is_map(values) do
    exact = Enum.sort(Map.keys(values)) == Enum.sort(@components)

    valid =
      Enum.all?(@components, fn component ->
        case values[component] do
          %{revision: revision, digest: digest} ->
            valid_digest?(revision) and valid_digest?(digest)

          _other ->
            false
        end
      end)

    if exact and valid, do: :ok, else: :error
  end

  defp components(_values), do: :error

  defp envelope(values) when is_map(values) do
    exact = Enum.sort(Map.keys(values)) == Enum.sort(@envelope_keys)

    valid =
      Enum.all?(@envelope_keys, fn key ->
        entries = values[key]

        is_list(entries) and entries != [] and length(entries) <= 64 and
          Enum.all?(entries, &(is_binary(&1) and byte_size(&1) in 1..128))
      end)

    if exact and valid, do: :ok, else: :error
  end

  defp envelope(_values), do: :error

  defp excluded?(request, rule), do: rule in Map.get(request, :matched_exclusions, [])

  defp digest(material) do
    material
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_production_profile)}
end
