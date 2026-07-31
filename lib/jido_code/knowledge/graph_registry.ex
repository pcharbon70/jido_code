defmodule JidoCode.Knowledge.GraphRegistry do
  @moduledoc """
  Closed registry of named graph families and their lifecycle contracts.

  Registry maps are executable configuration projections, not persisted domain
  records. Named graph metadata in the dataset remains authoritative.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @base "https://jido.run/graph/"
  @revision "1.0.0"

  @families %{
    ontology: %{
      required_scopes: [:version],
      capability: :ontology_release,
      mutability: :immutable,
      completeness: :complete,
      retention: :permanent,
      allowed_links: [:ontology]
    },
    factory_catalog: %{
      required_scopes: [],
      capability: :catalog_writer,
      mutability: :append_supersede,
      completeness: :complete,
      retention: :permanent,
      allowed_links: [:factory_catalog, :factory_policy, :security_audit]
    },
    factory_policy: %{
      required_scopes: [],
      capability: :policy_writer,
      mutability: :append_supersede,
      completeness: :complete,
      retention: :permanent,
      allowed_links: [:factory_catalog, :factory_policy, :repository_control, :security_audit]
    },
    observation_batch: %{
      required_scopes: [:repository, :batch],
      capability: :observation_writer,
      mutability: :immutable,
      completeness: :complete,
      retention: :observations,
      allowed_links: [:factory_catalog, :observation_batch, :source_revision]
    },
    source_revision: %{
      required_scopes: [:repository, :revision],
      capability: :source_writer,
      mutability: :immutable,
      completeness: :complete,
      retention: :source_history,
      allowed_links: [:factory_catalog, :observation_batch, :source_revision]
    },
    repository_control: %{
      required_scopes: [:repository],
      capability: :control_writer,
      mutability: :append_supersede,
      completeness: :complete,
      retention: :control_history,
      allowed_links: [
        :factory_catalog,
        :factory_policy,
        :observation_batch,
        :source_revision,
        :repository_control,
        :run_attempt,
        :evidence,
        :memory
      ]
    },
    run_attempt: %{
      required_scopes: [:attempt],
      capability: :execution_writer,
      mutability: :closeable,
      completeness: :building,
      retention: :run_history,
      allowed_links: [:factory_catalog, :source_revision, :repository_control, :run_attempt]
    },
    evidence: %{
      required_scopes: [:repository],
      capability: :evidence_writer,
      mutability: :append_supersede,
      completeness: :complete,
      retention: :evidence_history,
      allowed_links: [
        :observation_batch,
        :source_revision,
        :repository_control,
        :run_attempt,
        :evidence
      ]
    },
    memory: %{
      required_scopes: [:repository],
      capability: :memory_writer,
      mutability: :append_supersede,
      completeness: :complete,
      retention: :knowledge_history,
      allowed_links: [:factory_catalog, :repository_control, :evidence, :memory]
    },
    security_audit: %{
      required_scopes: [:period],
      capability: :security_auditor,
      mutability: :append_only,
      completeness: :complete,
      retention: :security_audit,
      allowed_links: [:factory_catalog, :factory_policy, :repository_control, :security_audit]
    },
    derived: %{
      required_scopes: [:rule_set, :revision],
      capability: :reasoner,
      mutability: :replaceable,
      completeness: :complete,
      retention: :disposable,
      allowed_links:
        Map.keys(%{
          ontology: true,
          factory_catalog: true,
          factory_policy: true,
          observation_batch: true,
          source_revision: true,
          repository_control: true,
          run_attempt: true,
          evidence: true,
          memory: true,
          security_audit: true,
          derived: true
        })
    }
  }

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec families() :: [atom()]
  def families, do: @families |> Map.keys() |> Enum.sort()

  @spec fetch(atom()) :: {:ok, map()} | {:error, Error.t()}
  def fetch(family) when is_atom(family) do
    case Map.fetch(@families, family) do
      {:ok, contract} -> {:ok, Map.put(contract, :family, family)}
      :error -> invalid(:graph_family)
    end
  end

  def fetch(_family), do: invalid(:graph_family)

  @spec graph_iri(atom(), map()) :: {:ok, String.t()} | {:error, Error.t()}
  def graph_iri(family, scopes) when is_atom(family) and is_map(scopes) do
    with {:ok, contract} <- fetch(family),
         :ok <- validate_scope_keys(scopes, contract.required_scopes),
         {:ok, suffix} <- graph_suffix(family, scopes),
         iri = @base <> suffix,
         true <- RDF.IRI.valid?(iri) and byte_size(iri) <= 512 do
      {:ok, iri}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:graph_identity)
    end
  end

  def graph_iri(_family, _scopes), do: invalid(:graph_identity)

  @spec identify(term()) :: {:ok, atom()} | {:error, Error.t()}
  def identify(%RDF.IRI{value: value}), do: identify(value)

  def identify(value) when is_binary(value) do
    case Enum.find(families(), &family_iri?(&1, value)) do
      nil -> invalid(:graph_identity)
      family -> {:ok, family}
    end
  end

  def identify(_value), do: invalid(:graph_identity)

  @spec validate_target(String.t(), atom()) :: {:ok, map()} | {:error, Error.t()}
  def validate_target(graph_iri, capability) when is_atom(capability) do
    with {:ok, family} <- identify(graph_iri),
         {:ok, contract} <- fetch(family),
         true <- contract.capability == capability do
      {:ok, contract}
    else
      {:error, %Error{} = error} -> {:error, error}
      _unauthorized -> {:error, Error.new(:unauthorized, :graph_writer_capability)}
    end
  end

  def validate_target(_graph_iri, _capability), do: invalid(:graph_writer_capability)

  @spec write_allowed?(atom(), :create | :append | :close | :replace, map() | nil) :: boolean()
  def write_allowed?(family, operation, existing_metadata \\ nil) do
    case {Map.get(@families, family), operation, existing_metadata} do
      {%{mutability: :immutable}, :create, nil} ->
        true

      {%{mutability: :append_only}, operation, metadata} when operation in [:create, :append] ->
        open_or_new?(metadata)

      {%{mutability: :append_supersede}, operation, metadata}
      when operation in [:create, :append] ->
        open_or_new?(metadata)

      {%{mutability: :closeable}, operation, nil} when operation in [:create] ->
        true

      {%{mutability: :closeable}, operation, metadata} when operation in [:append, :close] ->
        lifecycle(metadata) == :open

      {%{mutability: :replaceable}, operation, _metadata} when operation in [:create, :replace] ->
        true

      _other ->
        false
    end
  end

  @spec allowed_link?(atom(), atom()) :: boolean()
  def allowed_link?(source_family, target_family) do
    case Map.get(@families, source_family) do
      %{allowed_links: allowed} -> target_family in allowed
      _unknown -> false
    end
  end

  @spec graph_kind_iri(atom()) :: {:ok, String.t()} | {:error, Error.t()}
  def graph_kind_iri(family) do
    case family do
      :ontology -> ok_concept("OntologyGraph")
      :factory_catalog -> ok_concept("FactoryCatalogGraph")
      :factory_policy -> ok_concept("FactoryPolicyGraph")
      :observation_batch -> ok_concept("ObservationGraph")
      :source_revision -> ok_concept("SourceGraph")
      :repository_control -> ok_concept("ControlGraph")
      :run_attempt -> ok_concept("RunGraph")
      :evidence -> ok_concept("EvidenceGraph")
      :memory -> ok_concept("MemoryGraph")
      :security_audit -> ok_concept("SecurityAuditGraph")
      :derived -> ok_concept("DerivedGraph")
      _unknown -> invalid(:graph_family)
    end
  end

  defp graph_suffix(:ontology, %{version: version}) do
    if Regex.match?(~r/^\d+\.\d+\.\d+$/, version),
      do: {:ok, "ontology/#{version}"},
      else: invalid(:graph_scope)
  end

  defp graph_suffix(:factory_catalog, %{}), do: {:ok, "factory/catalog"}
  defp graph_suffix(:factory_policy, %{}), do: {:ok, "factory/policy"}

  defp graph_suffix(:observation_batch, %{repository: repository, batch: batch}) do
    two_resource_suffix("repo", repository, "observation", batch)
  end

  defp graph_suffix(:source_revision, %{repository: repository, revision: revision}) do
    two_resource_suffix("repo", repository, "source", revision)
  end

  defp graph_suffix(:repository_control, %{repository: repository}) do
    one_resource_suffix("repo", repository, "control")
  end

  defp graph_suffix(:run_attempt, %{attempt: attempt}) do
    with {:ok, token} <- ResourceIdentity.graph_token(attempt), do: {:ok, "run/#{token}"}
  end

  defp graph_suffix(:evidence, %{repository: repository}) do
    one_resource_suffix("repo", repository, "evidence")
  end

  defp graph_suffix(:memory, %{repository: repository}) do
    one_resource_suffix("repo", repository, "memory")
  end

  defp graph_suffix(:security_audit, %{period: period}) when is_binary(period) do
    if Regex.match?(~r/^\d{4}-(0[1-9]|1[0-2])$/, period),
      do: {:ok, "security/audit/#{period}"},
      else: invalid(:graph_scope)
  end

  defp graph_suffix(:derived, %{rule_set: rule_set, revision: revision})
       when is_binary(rule_set) and is_integer(revision) and revision >= 0 do
    if Regex.match?(~r/^[a-z][a-z0-9-]{0,63}$/, rule_set) do
      {:ok, "derived/#{rule_set}/#{revision}"}
    else
      invalid(:graph_scope)
    end
  end

  defp graph_suffix(_family, _scopes), do: invalid(:graph_scope)

  defp two_resource_suffix(prefix, first, middle, second) do
    with {:ok, first_token} <- ResourceIdentity.graph_token(first),
         {:ok, second_token} <- ResourceIdentity.graph_token(second) do
      {:ok, "#{prefix}/#{first_token}/#{middle}/#{second_token}"}
    end
  end

  defp one_resource_suffix(prefix, resource, suffix) do
    with {:ok, token} <- ResourceIdentity.graph_token(resource) do
      {:ok, "#{prefix}/#{token}/#{suffix}"}
    end
  end

  defp validate_scope_keys(scopes, required) do
    if scopes |> Map.keys() |> Enum.sort() == Enum.sort(required) do
      :ok
    else
      invalid(:graph_scope)
    end
  end

  defp family_iri?(:ontology, iri), do: Regex.match?(~r|^#{@base}ontology/\d+\.\d+\.\d+$|, iri)
  defp family_iri?(:factory_catalog, iri), do: iri == @base <> "factory/catalog"
  defp family_iri?(:factory_policy, iri), do: iri == @base <> "factory/policy"

  defp family_iri?(:observation_batch, iri),
    do: scoped_iri?(iri, ~r|^repo/[a-f0-9]{32}/observation/[a-f0-9]{32}$|)

  defp family_iri?(:source_revision, iri),
    do: scoped_iri?(iri, ~r|^repo/[a-f0-9]{32}/source/[a-f0-9]{32}$|)

  defp family_iri?(:repository_control, iri),
    do: scoped_iri?(iri, ~r|^repo/[a-f0-9]{32}/control$|)

  defp family_iri?(:run_attempt, iri), do: scoped_iri?(iri, ~r|^run/[a-f0-9]{32}$|)
  defp family_iri?(:evidence, iri), do: scoped_iri?(iri, ~r|^repo/[a-f0-9]{32}/evidence$|)
  defp family_iri?(:memory, iri), do: scoped_iri?(iri, ~r|^repo/[a-f0-9]{32}/memory$|)

  defp family_iri?(:security_audit, iri),
    do: scoped_iri?(iri, ~r/^security\/audit\/\d{4}-(?:0[1-9]|1[0-2])$/)

  defp family_iri?(:derived, iri),
    do: scoped_iri?(iri, ~r|^derived/[a-z][a-z0-9-]{0,63}/\d+$|)

  defp scoped_iri?(iri, pattern) do
    case String.split_at(iri, byte_size(@base)) do
      {@base, suffix} -> Regex.match?(pattern, suffix)
      _other -> false
    end
  end

  defp open_or_new?(nil), do: true
  defp open_or_new?(metadata), do: lifecycle(metadata) != :closed
  defp lifecycle(metadata) when is_map(metadata), do: Map.get(metadata, :lifecycle_state)
  defp lifecycle(_metadata), do: nil

  defp ok_concept(term), do: {:ok, "https://jido.run/ontology/concept/#{term}"}
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
