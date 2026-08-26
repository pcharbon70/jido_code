defmodule JidoCode.Knowledge.Control.AgentCatalog do
  @moduledoc "Scope-filtered native and delegated coding-agent catalog and exact resolver."

  alias JidoCode.Knowledge.Control.DelegatedAdapterRelease
  alias JidoCode.Knowledge.Control.DelegatedAgentAdmission
  alias JidoCode.Knowledge.Control.DelegatedAgentContract, as: Contract
  alias JidoCode.Knowledge.Control.DelegatedAgentProfile
  alias JidoCode.Knowledge.Control.DelegatedAgentReadiness
  alias JidoCode.Knowledge.Control.HarnessProfile
  alias JidoCode.Knowledge.Control.ManagedCodingProfile
  alias JidoCode.Knowledge.Control.ModelAccessProfile
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Product.AgentOffering

  @max_candidates 256
  @rollout ~w[evaluation shadow pilot production]a

  @spec project([map()], [map()], map()) :: {:ok, [AgentOffering.t()]} | {:error, Error.t()}
  def project(native_candidates, delegated_candidates, context)
      when is_list(native_candidates) and is_list(delegated_candidates) and is_map(context) do
    with :ok <- validate_context(context),
         true <- length(native_candidates) + length(delegated_candidates) <= @max_candidates,
         {:ok, entries} <- entries(native_candidates, delegated_candidates, context) do
      offerings =
        entries
        |> Enum.map(& &1.offering)
        |> Enum.sort_by(&{&1.display_name, &1.runtime_class, &1.reference})

      {:ok, offerings}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:agent_catalog)
    end
  rescue
    _error -> invalid(:agent_catalog)
  end

  def project(_native_candidates, _delegated_candidates, _context), do: invalid(:agent_catalog)

  @spec resolve(String.t(), [map()], [map()], map(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def resolve(reference, native_candidates, delegated_candidates, context, admission)
      when is_binary(reference) and is_list(native_candidates) and is_list(delegated_candidates) and
             is_map(context) and is_map(admission) do
    with :ok <- validate_context(context),
         {:ok, candidates} <- entries(native_candidates, delegated_candidates, context) do
      case {Map.get(context, :authorized?, true),
            Enum.filter(candidates, &secure_compare?(&1.offering.reference, reference))} do
        {false, _candidates} ->
          {:ok, %{outcome: :unauthorized}}

        {true, []} ->
          {:ok, %{outcome: :stale}}

        {true, [%{offering: %{selectable: false, limitations: limitations}}]} ->
          {:ok, %{outcome: unavailable_outcome(limitations)}}

        {true, [%{kind: :delegated} = entry]} ->
          delegated_admission(entry, context, admission)

        {true, [%{kind: :native} = entry]} ->
          native_admission(entry, context, admission)

        {true, _duplicates} ->
          {:ok, %{outcome: :rejected}}
      end
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:agent_catalog_resolution)
    end
  rescue
    _error -> invalid(:agent_catalog_resolution)
  end

  def resolve(_reference, _native, _delegated, _context, _admission),
    do: invalid(:agent_catalog_resolution)

  defp entries(native_candidates, delegated_candidates, context) do
    with {:ok, native} <- collect(native_candidates, &native_entry(&1, context)),
         {:ok, delegated} <- collect(delegated_candidates, &delegated_entry(&1, context)) do
      {:ok, native ++ delegated}
    end
  end

  defp collect(candidates, fun) do
    Enum.reduce_while(candidates, {:ok, []}, fn candidate, {:ok, entries} ->
      case fun.(candidate) do
        {:ok, nil} -> {:cont, {:ok, entries}}
        {:ok, entry} -> {:cont, {:ok, [entry | entries]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp delegated_entry(
         %{
           profile: %DelegatedAgentProfile{} = profile,
           adapter: %DelegatedAdapterRelease{} = adapter,
           model_access: %ModelAccessProfile{} = access,
           harness: %HarnessProfile{} = harness,
           lifecycle: lifecycle
         } = candidate,
         context
       ) do
    if scoped?(profile, context) and visible?(profile, adapter, lifecycle, context.at) do
      readiness = Map.get(candidate, :readiness)

      limitations =
        delegated_limitations(profile, adapter, access, harness, readiness, lifecycle, context)

      selectable = limitations == []
      reference = delegated_reference(candidate, context)
      readiness_state = readiness_state(readiness, context.at)

      offering = %AgentOffering{
        reference: reference,
        display_name: profile.display_name,
        description: bounded_description(candidate, "Delegated coding CLI through JidoHarness"),
        runtime_class: :delegated_cli,
        provider: profile.provider,
        deployment_class: profile.deployment_class,
        authentication_kind: profile.authentication_kind,
        billing_mode: profile.billing_mode,
        capability_class: profile.capability_class,
        capability_summary: capability_summary(profile.capability_class),
        task_classes: profile.task_classes,
        language_classes: profile.language_classes,
        readiness: readiness_state,
        readiness_age_seconds: readiness_age(readiness, context.at),
        rollout_stage: profile.rollout_stage,
        profile_revision: profile.revision,
        profile_digest: profile.profile_digest,
        limitations: limitations,
        selectable: selectable
      }

      {:ok, %{kind: :delegated, offering: offering, candidate: candidate}}
    else
      {:ok, nil}
    end
  end

  defp delegated_entry(_candidate, _context), do: invalid(:delegated_agent_catalog_candidate)

  defp native_entry(
         %{
           profile: %ManagedCodingProfile{} = profile,
           model_access: %ModelAccessProfile{} = access,
           lifecycle: lifecycle,
           language_classes: language_classes,
           readiness: readiness
         } = candidate,
         context
       ) do
    with {:ok, display_name} <- Contract.text(candidate[:display_name], 128),
         {:ok, description} <- Contract.text(candidate[:description], 512),
         {:ok, provider} <- Contract.identifier(candidate[:provider], 64),
         {:ok, language_classes} <- Contract.identifiers(language_classes, 32, 64),
         true <- native_scoped?(profile, language_classes, context) do
      state = lifecycle[:current_state]
      visible = state in [:disabled, :enabled]

      if visible do
        limitations =
          native_limitations(profile, access, lifecycle, readiness, candidate, context)

        reference = native_reference(candidate, context)

        offering = %AgentOffering{
          reference: reference,
          display_name: display_name,
          description: description,
          runtime_class: :host_controlled,
          provider: provider,
          deployment_class: Map.get(candidate, :deployment_class, :managed_fleet),
          authentication_kind: Map.get(candidate, :authentication_kind, :api_key),
          billing_mode: access.billing_mode,
          capability_class:
            Map.get(candidate, :capability_class, :workspace_write_registered_checks),
          capability_summary:
            capability_summary(
              Map.get(candidate, :capability_class, :workspace_write_registered_checks)
            ),
          task_classes: profile.task_classes,
          language_classes: language_classes,
          readiness: readiness_state(readiness, context.at),
          readiness_age_seconds: readiness_age(readiness, context.at),
          rollout_stage: Map.get(candidate, :rollout_stage, :production),
          profile_revision: profile.revision,
          profile_digest: profile.profile_digest,
          limitations: limitations,
          selectable: limitations == []
        }

        {:ok, %{kind: :native, offering: offering, candidate: candidate}}
      else
        {:ok, nil}
      end
    else
      _invalid -> invalid(:native_agent_catalog_candidate)
    end
  end

  defp native_entry(_candidate, _context), do: invalid(:native_agent_catalog_candidate)

  defp delegated_limitations(profile, adapter, access, harness, readiness, lifecycle, context) do
    []
    |> add_unless(lifecycle[:current_state] == :enabled, :profile_disabled)
    |> add_unless(profile.rollout_stage in @rollout, :rollout_disabled)
    |> add_unless(access.access_mode == :delegated_cli, :access_mode_incompatible)
    |> add_unless(access.provider == Atom.to_string(profile.provider), :provider_incompatible)
    |> add_unless(access.billing_mode == profile.billing_mode, :billing_incompatible)
    |> add_unless(profile.adapter_release_iri == adapter.iri, :adapter_release_incompatible)
    |> add_unless(adapter.provider == profile.provider, :provider_incompatible)
    |> add_unless(adapter.state == :accepted, :adapter_unavailable)
    |> add_unless(
      profile.prompt_transport == adapter.prompt_transport,
      :prompt_transport_incompatible
    )
    |> add_unless(
      profile.capability_class in adapter.capability_classes,
      :capability_incompatible
    )
    |> add_unless(
      profile.deployment_class in adapter.deployment_classes,
      :deployment_incompatible
    )
    |> add_unless(profile.harness_profile_iri == harness.iri, :harness_incompatible)
    |> add_unless(profile.model_access_profile_iri == access.iri, :access_profile_incompatible)
    |> add_unless(harness.model_access_profile_iri == access.iri, :harness_incompatible)
    |> add_unless(
      harness.tool_catalog_version == profile.tool_manifest_digest,
      :tool_manifest_incompatible
    )
    |> add_unless(
      harness.policy_revision == profile.workspace_policy_revision,
      :workspace_policy_incompatible
    )
    |> add_unless(harness.budget_profile == Contract.digest(profile.budget), :budget_incompatible)
    |> add_unless(
      adapter.candidate_protocol_revision == profile.candidate_protocol_revision,
      :candidate_protocol_incompatible
    )
    |> add_unless(
      readiness_compatible?(readiness, profile, adapter, context.at),
      :readiness_unavailable
    )
    |> Enum.reverse()
  end

  defp native_limitations(profile, access, lifecycle, readiness, candidate, context) do
    []
    |> add_unless(lifecycle[:current_state] == :enabled, :profile_disabled)
    |> add_unless(Map.get(candidate, :rollout_stage, :production) in @rollout, :rollout_disabled)
    |> add_unless(access.iri == profile.model_access_profile_iri, :access_profile_incompatible)
    |> add_unless(
      access.access_mode in [:host_api, :host_subscription],
      :access_mode_incompatible
    )
    |> add_unless(native_readiness?(readiness, context.at), :readiness_unavailable)
    |> Enum.reverse()
  end

  defp readiness_compatible?(%DelegatedAgentReadiness{} = readiness, profile, adapter, at) do
    readiness.profile_iri == profile.iri and readiness.profile_digest == profile.profile_digest and
      readiness.adapter_release_iri == adapter.iri and
      readiness.adapter_release_digest == adapter.release_digest and
      readiness.cli_version in adapter.cli_versions and
      readiness.sandbox_profile_revision == profile.sandbox_profile_revision and
      readiness.network_policy_revision == profile.network_policy_revision and
      readiness.verification_profile_revision == profile.verification_profile_revision and
      readiness.candidate_protocol_revision == profile.candidate_protocol_revision and
      DelegatedAgentReadiness.selectable?(readiness, at)
  end

  defp readiness_compatible?(_readiness, _profile, _adapter, _at), do: false

  defp native_readiness?(
         %{ready?: true, observed_at: %DateTime{} = observed, expires_at: %DateTime{} = expires},
         at
       ),
       do: DateTime.compare(observed, at) in [:lt, :eq] and DateTime.compare(at, expires) == :lt

  defp native_readiness?(_readiness, _at), do: false

  defp visible?(profile, adapter, lifecycle, at) do
    lifecycle[:current_state] in [:disabled, :enabled] and adapter.state == :accepted and
      DateTime.compare(profile.approved_at, at) in [:lt, :eq] and
      DateTime.compare(at, profile.expires_at) == :lt and
      DateTime.compare(adapter.approved_at, at) in [:lt, :eq] and
      DateTime.compare(at, adapter.expires_at) == :lt
  end

  defp scoped?(profile, context) do
    context.actor_iri in profile.actor_iris and context.tenant_iri in profile.tenant_iris and
      context.repository_iri in profile.repository_iris and
      context.capability_iri in profile.capability_iris and
      context.task_class in profile.task_classes and
      context.language_class in profile.language_classes
  end

  defp native_scoped?(profile, language_classes, context) do
    context.actor_iri in profile.actor_iris and context.tenant_iri in profile.tenant_iris and
      context.repository_iri in profile.repository_iris and
      context.capability_iri in profile.capability_iris and
      context.task_class in profile.task_classes and context.language_class in language_classes
  end

  defp delegated_reference(candidate, context) do
    readiness_digest =
      case candidate[:readiness] do
        %DelegatedAgentReadiness{observation_digest: digest} -> digest
        _missing -> "unavailable"
      end

    material = [
      "delegated",
      candidate.profile.profile_digest,
      candidate.adapter.release_digest,
      readiness_digest,
      Contract.digest(Map.from_struct(candidate.model_access)),
      Contract.digest(Map.from_struct(candidate.harness)),
      candidate.lifecycle[:current_transition],
      candidate.lifecycle[:current_revision],
      candidate.lifecycle[:current_state],
      context_material(context)
    ]

    opaque_reference(context.selection_key, material)
  end

  defp native_reference(candidate, context) do
    readiness_digest = Contract.digest(candidate.readiness)

    opaque_reference(context.selection_key, [
      "native",
      candidate.profile.profile_digest,
      Contract.digest(Map.from_struct(candidate.model_access)),
      candidate.lifecycle[:current_transition],
      candidate.lifecycle[:current_revision],
      candidate.lifecycle[:current_state],
      readiness_digest,
      context_material(context)
    ])
  end

  defp context_material(context) do
    Contract.digest(%{
      actor: context.actor_iri,
      tenant: context.tenant_iri,
      repository: context.repository_iri,
      capability: context.capability_iri,
      task: context.task_class,
      language: context.language_class,
      source_snapshot: context.source_snapshot_iri,
      graph_revisions: context.source_graph_revisions
    })
  end

  defp opaque_reference(key, material) do
    digest = :crypto.mac(:hmac, :sha256, key, Enum.map_join(material, "\n", &to_string/1))
    "agent_" <> Base.url_encode64(digest, padding: false)
  end

  defp delegated_admission(entry, context, admission) do
    candidate = entry.candidate
    readiness = candidate.readiness

    attributes = %{
      offering_reference: entry.offering.reference,
      profile_iri: candidate.profile.iri,
      profile_digest: candidate.profile.profile_digest,
      runtime_class: :delegated_cli,
      adapter_release_iri: candidate.adapter.iri,
      adapter_release_digest: candidate.adapter.release_digest,
      harness_profile_iri: candidate.harness.iri,
      model_access_profile_iri: candidate.model_access.iri,
      deployment_class: candidate.profile.deployment_class,
      authentication_kind: candidate.profile.authentication_kind,
      billing_mode: candidate.profile.billing_mode,
      capability_class: candidate.profile.capability_class,
      readiness_iri: readiness.iri,
      readiness_digest: readiness.observation_digest,
      credential_generation: readiness.credential_generation,
      workspace_policy_revision: candidate.profile.workspace_policy_revision,
      sandbox_profile_revision: candidate.profile.sandbox_profile_revision,
      network_policy_revision: candidate.profile.network_policy_revision,
      candidate_protocol_revision: candidate.profile.candidate_protocol_revision,
      verification_profile_revision: candidate.profile.verification_profile_revision,
      source_snapshot_iri: context.source_snapshot_iri,
      source_graph_revisions: context.source_graph_revisions,
      attempt_iri: admission[:attempt_iri],
      lease_iri: admission[:lease_iri],
      fencing_token: admission[:fencing_token],
      invocation_before_effect_iri: admission[:invocation_before_effect_iri],
      bound_at: admission[:bound_at]
    }

    attributes =
      Map.put(attributes, :binding_digest, DelegatedAgentAdmission.binding_digest(attributes))

    case DelegatedAgentAdmission.new(attributes) do
      {:ok, binding} ->
        if secure_compare_optional?(admission[:existing_binding_digest], binding.binding_digest) do
          {:ok, %{outcome: :duplicate, binding_digest: binding.binding_digest}}
        else
          {:ok, %{outcome: :admitted, binding: binding}}
        end

      {:error, %Error{}} ->
        {:ok, %{outcome: :rejected}}
    end
  end

  defp native_admission(entry, context, admission) do
    resources = ~w[attempt_iri lease_iri invocation_before_effect_iri]a

    if Enum.all?(resources, &(ResourceIdentity.validate(admission[&1]) == :ok)) and
         is_integer(admission[:fencing_token]) and admission.fencing_token > 0 and
         match?(%DateTime{}, admission[:bound_at]) do
      candidate = entry.candidate

      {:ok,
       %{
         outcome: :admitted,
         binding: %{
           offering_reference: entry.offering.reference,
           runtime_class: :host_controlled,
           profile_iri: candidate.profile.iri,
           profile_digest: candidate.profile.profile_digest,
           model_access_profile_iri: candidate.model_access.iri,
           source_snapshot_iri: context.source_snapshot_iri,
           source_graph_revisions: context.source_graph_revisions,
           attempt_iri: admission.attempt_iri,
           lease_iri: admission.lease_iri,
           fencing_token: admission.fencing_token,
           invocation_before_effect_iri: admission.invocation_before_effect_iri,
           bound_at: admission.bound_at
         }
       }}
    else
      {:ok, %{outcome: :rejected}}
    end
  end

  defp validate_context(context) do
    resources = ~w[actor_iri tenant_iri repository_iri capability_iri source_snapshot_iri]a

    cond do
      not Enum.all?(resources, &(ResourceIdentity.validate(context[&1]) == :ok)) ->
        :error

      not match?(%DateTime{}, context[:at]) ->
        :error

      not valid_selection_key?(context[:selection_key]) ->
        :error

      not valid_class?(context[:task_class]) or not valid_class?(context[:language_class]) ->
        :error

      not valid_revisions?(context[:source_graph_revisions]) ->
        :error

      true ->
        :ok
    end
  end

  defp valid_selection_key?(key),
    do: is_binary(key) and byte_size(key) >= 32 and byte_size(key) <= 128

  defp valid_class?(value), do: match?({:ok, _}, Contract.identifier(value, 64))

  defp valid_revisions?(revisions) when is_map(revisions) and map_size(revisions) > 0 do
    Enum.all?(revisions, fn {graph, revision} ->
      is_binary(graph) and RDF.IRI.valid?(graph) and is_integer(revision) and revision >= 0
    end)
  end

  defp valid_revisions?(_revisions), do: false

  defp readiness_state(%DelegatedAgentReadiness{} = readiness, at),
    do: if(DelegatedAgentReadiness.selectable?(readiness, at), do: :ready, else: :stale)

  defp readiness_state(%{ready?: true} = readiness, at),
    do: if(native_readiness?(readiness, at), do: :ready, else: :stale)

  defp readiness_state(_readiness, _at), do: :unavailable

  defp readiness_age(%DelegatedAgentReadiness{} = readiness, at),
    do: max(DateTime.diff(at, readiness.observed_at, :second), 0)

  defp readiness_age(%{observed_at: %DateTime{} = observed_at}, at),
    do: max(DateTime.diff(at, observed_at, :second), 0)

  defp readiness_age(_readiness, _at), do: nil

  defp bounded_description(candidate, default) do
    case Contract.text(Map.get(candidate, :description, default), 512) do
      {:ok, value} -> value
      :error -> default
    end
  end

  defp capability_summary(:deny_all), do: "No CLI tools"
  defp capability_summary(:bounded_read_only), do: "Bounded workspace reads"
  defp capability_summary(:workspace_write), do: "Disposable workspace writes"

  defp capability_summary(:workspace_write_registered_checks),
    do: "Workspace writes and registered checks"

  defp capability_summary(_capability), do: "Bounded native coding capability"

  defp add_unless(limitations, true, _limitation), do: limitations
  defp add_unless(limitations, false, limitation), do: [limitation | limitations]

  defp unavailable_outcome(limitations) do
    if Enum.any?(limitations, &String.ends_with?(Atom.to_string(&1), "_incompatible")),
      do: :incompatible,
      else: :unavailable
  end

  defp secure_compare?(left, right) when byte_size(left) == byte_size(right),
    do: Plug.Crypto.secure_compare(left, right)

  defp secure_compare?(_left, _right), do: false

  defp secure_compare_optional?(nil, _right), do: false
  defp secure_compare_optional?(left, right), do: secure_compare?(left, right)
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
