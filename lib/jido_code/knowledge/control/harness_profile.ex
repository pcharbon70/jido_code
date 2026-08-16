defmodule JidoCode.Knowledge.Control.HarnessProfile do
  @moduledoc """
  Versioned harness profile pinning workflow, prompt, model-access, tool,
  policy, and budget contract revisions.

  A harness profile is the versioned configuration surface an execution
  attempt cites. It never contains executable content, credentials, or
  prompt bodies - only version identities of separately governed contracts.
  """

  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :name,
    :version,
    :owner_iri,
    :scope_iri,
    :model_access_profile_iri,
    :workflow_version,
    :prompt_template_version,
    :tool_catalog_version,
    :policy_revision,
    :budget_profile
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with {:ok, name} <- bounded_text(attributes[:name], 128),
         {:ok, version} <- bounded_text(attributes[:version], 32),
         :ok <- ResourceIdentity.validate(attributes[:owner_iri]),
         :ok <- ResourceIdentity.validate(attributes[:scope_iri]),
         :ok <- ResourceIdentity.validate(attributes[:model_access_profile_iri]),
         {:ok, workflow_version} <- bounded_text(attributes[:workflow_version], 64),
         {:ok, prompt_template_version} <- bounded_text(attributes[:prompt_template_version], 64),
         {:ok, tool_catalog_version} <- bounded_text(attributes[:tool_catalog_version], 64),
         {:ok, policy_revision} <- bounded_text(attributes[:policy_revision], 64),
         {:ok, budget_profile} <- bounded_text(attributes[:budget_profile], 64),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :harness_profile,
             Enum.join([attributes.owner_iri, name, version], "\n")
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         name: name,
         version: version,
         owner_iri: attributes.owner_iri,
         scope_iri: attributes.scope_iri,
         model_access_profile_iri: attributes.model_access_profile_iri,
         workflow_version: workflow_version,
         prompt_template_version: prompt_template_version,
         tool_catalog_version: tool_catalog_version,
         policy_revision: policy_revision,
         budget_profile: budget_profile
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:harness_profile)
    end
  rescue
    _error -> invalid(:harness_profile)
  end

  def new(_attributes), do: invalid(:harness_profile)

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = profile) do
    [
      {profile.iri, @rdf_type, RDF.iri(@jf <> "HarnessProfile")},
      {profile.iri, @jf <> "displayId", RDF.XSD.String.new(profile.name)},
      {profile.iri, @jf <> "version", RDF.XSD.String.new(profile.version)},
      {profile.iri, @jf <> "usesModelAccessProfile", RDF.iri(profile.model_access_profile_iri)},
      {profile.iri, @jf <> "workflowVersion", RDF.XSD.String.new(profile.workflow_version)},
      {profile.iri, @jf <> "promptTemplateVersion",
       RDF.XSD.String.new(profile.prompt_template_version)},
      {profile.iri, @jf <> "toolCatalogVersion",
       RDF.XSD.String.new(profile.tool_catalog_version)},
      {profile.iri, @jf <> "policyRevision", RDF.XSD.String.new(profile.policy_revision)},
      {profile.iri, @jf <> "budgetProfile", RDF.XSD.String.new(profile.budget_profile)},
      {profile.iri, @jf <> "ownedBy", RDF.iri(profile.owner_iri)},
      {profile.iri, @jf <> "validFor", RDF.iri(profile.scope_iri)},
      {profile.iri, @prov <> "wasAttributedTo", RDF.iri(profile.owner_iri)}
    ]
  end

  @spec adopt_command(t(), map(), keyword()) ::
          {:ok, CommandEnvelope.t()} | {:error, Error.t()}
  def adopt_command(profile, attributes, options \\ [])

  def adopt_command(%__MODULE__{} = profile, attributes, options)
      when is_map(attributes) and is_list(options) do
    graph = attributes[:policy_graph_iri]

    with {:ok, :factory_policy} <- GraphRegistry.identify(graph),
         true <-
           is_integer(attributes[:expected_policy_revision]) and
             attributes[:expected_policy_revision] > 0,
         {:ok, command_iri} <-
           ResourceIdentity.deterministic(:command_request, profile.iri <> "\nadopt"),
         {:ok, command} <-
           CommandEnvelope.new(
             envelope("AdoptHarnessProfile", command_iri, profile, attributes, graph, [
               %{
                 family: :factory_policy,
                 graph_iri: graph,
                 operation: :append,
                 metadata: %{lifecycle_state: :open},
                 additions: statements(profile),
                 supersessions: [],
                 invalidations: [],
                 removals: []
               }
             ]),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:adopt_harness_profile)
    end
  end

  def adopt_command(_profile, _attributes, _options), do: invalid(:adopt_harness_profile)

  defp envelope(type, command_iri, profile, attributes, graph, changes) do
    %{
      command_type: type,
      command_version: "1.8.0",
      command_iri: command_iri,
      principal_iri: attributes[:principal_iri],
      actor_iri: attributes[:actor_iri],
      delegated_agent_iri: Map.get(attributes, :delegated_agent_iri),
      delegation_iri: Map.get(attributes, :delegation_iri),
      scope_iri: attributes[:scope_iri],
      idempotency_key: command_iri,
      correlation_iri: attributes[:correlation_iri],
      causation_iri: attributes[:causation_iri],
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: attributes[:expected_dataset_revision],
      expected_graph_revisions: %{graph => attributes[:expected_policy_revision]},
      reason: attributes[:reason],
      payload: %{
        changes: changes,
        guards: [
          {:subject_absent, graph, profile.iri},
          {:subject_present, graph, profile.model_access_profile_iri}
        ]
      }
    }
  end

  defp bounded_text(value, maximum) when is_binary(value) and byte_size(value) in 1..maximum//1,
    do: {:ok, value}

  defp bounded_text(_value, _maximum), do: invalid(:harness_profile_text)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
