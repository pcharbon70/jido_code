defmodule JidoCode.Identity.AuthorityBuilder do
  @moduledoc """
  Single trusted constructor for named-human product identity, scope, and authority.

  The builder accepts a verified server-side session reference and a closed
  `AuthorityRequest`. Browser roles, actors, grants, scope, delegations,
  assurance, and revisions have no input path.
  """

  alias JidoCode.Identity.AuthorityRequest
  alias JidoCode.Identity.AuthorizationResult
  alias JidoCode.Identity.Sessions
  alias JidoCode.Identity.Store
  alias JidoCode.Knowledge.AuthorityContext

  @safe_outcomes [
    :allowed,
    :concealed_not_found,
    :redacted,
    :denied,
    :unavailable,
    :revoked,
    :step_up_required
  ]

  @spec request(atom(), atom(), atom(), :factory | String.t(), keyword()) ::
          {:ok, AuthorityRequest.t()} | {:error, :invalid_authority_request}
  def request(operation, area, action, resource_ref \\ :factory, options \\ []) do
    AuthorityRequest.new(%{
      operation: operation,
      area: area,
      action: action,
      resource_ref: resource_ref,
      reauthorization_point: Keyword.get(options, :reauthorization_point, :before_response_start),
      correlation_ref:
        Keyword.get(options, :correlation_ref, reference("authorization_correlation"))
    })
  end

  @spec build(String.t(), AuthorityRequest.t(), keyword()) ::
          {:ok, AuthorizationResult.t()} | {:error, atom()}
  def build(session_ref, request, options \\ [])

  def build(session_ref, %AuthorityRequest{} = request, options)
      when is_binary(session_ref) do
    server = Keyword.get(options, :server, Store)
    now = Keyword.get(options, :now, DateTime.utc_now())

    with {:ok, request} <- AuthorityRequest.validate(request),
         {:ok, %{session: session, account: account}} <-
           Sessions.validate(session_ref,
             server: server,
             now: now,
             touch: Keyword.get(options, :touch, true)
           ),
         {:ok, snapshot} <- Store.authorization_snapshot(server, account.subject_ref, now: now),
         {:ok, resource} <- resolve_resource(server, request.resource_ref),
         identity <- product_identity(account),
         {:ok, authority_context} <- authority_context(identity) do
      result = decide(snapshot, session, identity, authority_context, resource, request, now)

      case record_decision(
             server,
             result,
             request,
             account.subject_ref,
             resource.resource_ref,
             now
           ) do
        :ok -> {:ok, result}
        {:error, :authorization_stale} -> {:ok, revoked_result(result, request)}
        {:error, _reason} -> {:ok, unavailable_result(result, request)}
      end
    else
      {:error, :invalid_authority_request} -> {:error, :invalid_authority_request}
      {:error, :not_found} -> {:error, :concealed_not_found}
      {:error, reason} when reason in [:expired, :revoked, :invalid_session] -> {:error, :revoked}
      {:error, _reason} -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  catch
    :exit, _reason -> {:error, :unavailable}
  end

  def build(_session_ref, _request, _options), do: {:error, :invalid_authority_request}

  @spec reauthorize(AuthorizationResult.t(), AuthorityRequest.t(), atom(), keyword()) ::
          {:ok, AuthorizationResult.t()} | {:error, atom()}
  def reauthorize(%AuthorizationResult{current_scope: scope}, request, point, options \\ [])
      when point in [
             :before_response_start,
             :before_query_execution,
             :before_field_shaping,
             :before_stream_subscription,
             :before_each_protected_patch,
             :before_command_construction,
             :inside_command_gateway,
             :before_approval_commit,
             :before_export_creation,
             :before_each_export_or_download_retrieval
           ] do
    next_request = %{request | reauthorization_point: point}
    build(scope.session_ref, next_request, options)
  end

  defp decide(snapshot, session, identity, context, resource, request, now) do
    memberships = scoped_memberships(snapshot.memberships, resource)
    roles = memberships |> Enum.flat_map(& &1.roles) |> Enum.uniq() |> Enum.sort()

    decision =
      cond do
        memberships == [] ->
          {:error, :concealed_not_found}

        not route_membership?(memberships, request.area) ->
          {:error, :concealed_not_found}

        resource.lifecycle == :archived and request.action not in [:page, :query, :field] ->
          {:error, :denied}

        not assurance_sufficient?(session, resource, request.action, now) ->
          {:error, :step_up_required}

        true ->
          resolve_grant(
            snapshot.authority_adapter,
            identity,
            memberships,
            snapshot.delegations,
            resource,
            request
          )
      end

    case decision do
      {:ok, grant} ->
        allowed_result(
          snapshot,
          session,
          identity,
          context,
          resource,
          request,
          roles,
          grant
        )

      {:error, outcome} when outcome in @safe_outcomes ->
        denied_result(
          snapshot,
          session,
          identity,
          context,
          resource,
          request,
          roles,
          outcome
        )

      _invalid ->
        denied_result(
          snapshot,
          session,
          identity,
          context,
          resource,
          request,
          roles,
          :unavailable
        )
    end
  end

  defp allowed_result(snapshot, session, identity, context, resource, request, roles, grant) do
    with true <- is_map(grant),
         true <- MapSet.subset?(MapSet.new(Map.keys(grant)), grant_keys()),
         grant_ref when is_binary(grant_ref) <- grant[:grant_ref],
         true <- valid_iri?(grant_ref),
         :ok <- valid_obligations?(grant[:obligations] || []),
         :ok <- valid_graph_revisions?(grant[:graph_revisions] || %{}),
         :ok <-
           exact_delegation?(
             grant[:delegation_ref],
             snapshot.delegations,
             session,
             resource,
             request
           ) do
      %AuthorizationResult{
        decision: :allowed,
        safe_reason: :current_exact_grant,
        current_scope: current_scope(snapshot, session, identity, resource),
        product_identity: identity,
        authority_context: context,
        membership_explanations: roles,
        exact_grant_ref: grant_ref,
        delegation_ref: grant[:delegation_ref],
        obligations: grant[:obligations] || [],
        policy_revision: snapshot.policy_revision,
        graph_revisions: grant[:graph_revisions] || %{},
        audit_correlation_ref: request.correlation_ref,
        concealment: :none,
        redaction: :minimum_authorized_projection
      }
    else
      _invalid ->
        denied_result(
          snapshot,
          session,
          identity,
          context,
          resource,
          request,
          roles,
          :unavailable
        )
    end
  end

  defp denied_result(snapshot, session, identity, context, resource, request, roles, outcome) do
    %AuthorizationResult{
      decision: outcome,
      safe_reason: safe_reason(outcome),
      current_scope: current_scope(snapshot, session, identity, resource),
      product_identity: identity,
      authority_context: context,
      membership_explanations: roles,
      exact_grant_ref: nil,
      delegation_ref: nil,
      obligations: [],
      policy_revision: snapshot.policy_revision,
      graph_revisions: %{},
      audit_correlation_ref: request.correlation_ref,
      concealment: if(outcome == :concealed_not_found, do: :conceal_resource, else: :none),
      redaction: if(outcome == :redacted, do: :omit_protected_fields, else: :none)
    }
  end

  defp unavailable_result(result, request) do
    %{
      result
      | decision: :unavailable,
        safe_reason: :authority_evidence_unavailable,
        exact_grant_ref: nil,
        delegation_ref: nil,
        obligations: [],
        graph_revisions: %{},
        audit_correlation_ref: request.correlation_ref
    }
  end

  defp revoked_result(result, request) do
    %{
      result
      | decision: :revoked,
        safe_reason: :authority_revoked,
        exact_grant_ref: nil,
        delegation_ref: nil,
        obligations: [],
        graph_revisions: %{},
        audit_correlation_ref: request.correlation_ref
    }
  end

  defp current_scope(snapshot, session, identity, resource) do
    %{
      iri: resource.graph_scope_iri,
      actor_iri: identity.actor_iri,
      principal_iri: identity.principal_iri,
      subject_ref: identity.subject_ref,
      display_name: identity.display_name,
      tenant_ref: resource.tenant_ref,
      project_ref: resource.project_ref,
      resource_ref: resource.resource_ref,
      resource_kind: resource.kind,
      resource_revision: resource.registry_revision,
      classification: resource.classification,
      environment: resource.environment,
      authenticated_at: DateTime.to_unix(session.last_authenticated_at),
      expires_at: DateTime.to_unix(session.hard_expires_at),
      idle_expires_at: DateTime.to_unix(session.idle_expires_at),
      assurance: session.assurance,
      session_ref: session.session_ref,
      session_generation: session.session_generation,
      account_generation: session.account_generation,
      policy_revision: snapshot.policy_revision,
      revocation_generations: snapshot.generations,
      nonce: session.nonce,
      identity: identity,
      principal_class: :human
    }
  end

  defp scoped_memberships(memberships, resource) do
    Enum.filter(memberships, fn membership ->
      membership.tenant_ref == resource.tenant_ref and
        membership.project_ref == resource.project_ref and
        clearance_rank(membership.clearance) >= classification_rank(resource.classification)
    end)
  end

  defp route_membership?(memberships, area),
    do: Enum.any?(memberships, &(area in &1.route_groups))

  defp assurance_sufficient?(session, resource, action, now) do
    {minimum, maximum_age_seconds} = assurance_rule(resource.classification, action)
    age = DateTime.diff(now, session.last_authenticated_at, :second)

    assurance_rank(session.assurance) >= assurance_rank(minimum) and
      age in 0..maximum_age_seconds
  end

  defp assurance_rule(_classification, action)
       when action in [:command, :export, :download],
       do: {:action_bound_step_up, 600}

  defp assurance_rule(classification, _action)
       when classification in [:confidential, :secret_reference, :audit, :personal],
       do: {:phishing_resistant, 14_400}

  defp assurance_rule(_classification, _action), do: {:baseline, 43_200}

  defp exact_delegation?(nil, _delegations, _session, _resource, _request), do: :ok

  defp exact_delegation?(delegation_ref, delegations, session, resource, request) do
    matches =
      Enum.filter(delegations, fn delegation ->
        delegation.delegation_ref == delegation_ref and
          resource.resource_ref in delegation.resource_refs and
          request.action in delegation.actions and
          resource.environment == delegation.environment and
          assurance_rank(delegation.minimum_assurance) <= assurance_rank(session.assurance) and
          classification_rank(resource.classification) <=
            classification_rank(delegation.maximum_classification)
      end)

    if length(matches) == 1, do: :ok, else: {:error, :invalid_delegation}
  end

  defp resolve_resource(server, resource_ref), do: Store.resolve_resource(server, resource_ref)

  defp resolve_grant(adapter, identity, memberships, delegations, resource, request) do
    adapter.resolve(identity, memberships, delegations, resource, request)
  rescue
    _error -> {:error, :unavailable}
  catch
    _kind, _reason -> {:error, :unavailable}
  end

  defp authority_context(identity) do
    AuthorityContext.new(%{
      principal_iri: identity.principal_iri,
      actor_iri: identity.actor_iri,
      delegated_agent_iri: nil,
      delegation_iri: nil
    })
  end

  defp product_identity(account) do
    surface = Application.fetch_env!(:jido_code, :product_surface)
    human_iri = "https://jido.run/id/human/#{account.subject_ref}"

    %{
      subject_ref: account.subject_ref,
      display_name: account.display_name,
      factory_iri: Keyword.fetch!(surface, :factory_iri),
      factory_scope_iri: Keyword.fetch!(surface, :factory_scope_iri),
      policy_boundary_iri: Keyword.fetch!(surface, :policy_boundary_iri),
      policy_iris: Keyword.fetch!(surface, :policy_iris),
      principal_iri: human_iri,
      actor_iri: human_iri
    }
  end

  defp record_decision(server, result, request, subject_ref, resource_ref, now) do
    Store.record_authorization(
      server,
      %{
        actor_ref: subject_ref,
        operation: request.operation,
        outcome: result.decision,
        resource_ref: resource_ref,
        correlation_ref: request.correlation_ref,
        session_ref: result.current_scope.session_ref,
        session_generation: result.current_scope.session_generation,
        account_generation: result.current_scope.account_generation,
        policy_revision: result.current_scope.policy_revision,
        revocation_generations: result.current_scope.revocation_generations,
        resource_revision: result.current_scope.resource_revision
      },
      now: now
    )
  end

  defp safe_reason(:allowed), do: :current_exact_grant
  defp safe_reason(:concealed_not_found), do: :resource_not_available
  defp safe_reason(:redacted), do: :field_not_available
  defp safe_reason(:denied), do: :operation_not_allowed
  defp safe_reason(:unavailable), do: :authority_evidence_unavailable
  defp safe_reason(:revoked), do: :authority_revoked
  defp safe_reason(:step_up_required), do: :current_assurance_required

  defp valid_iri?(value) when is_binary(value) do
    uri = URI.parse(value)
    uri.scheme in ["http", "https", "urn"] and is_nil(uri.userinfo) and is_nil(uri.fragment)
  end

  defp valid_iri?(_value), do: false

  defp valid_obligations?(obligations)
       when is_list(obligations) and length(obligations) <= 32 do
    if Enum.all?(obligations, &is_atom/1), do: :ok, else: {:error, :invalid_obligations}
  end

  defp valid_obligations?(_obligations), do: {:error, :invalid_obligations}

  defp valid_graph_revisions?(revisions) when is_map(revisions) and map_size(revisions) <= 64 do
    if Enum.all?(revisions, fn {graph_iri, revision} ->
         valid_iri?(graph_iri) and is_integer(revision) and revision >= 0
       end),
       do: :ok,
       else: {:error, :invalid_graph_revisions}
  end

  defp valid_graph_revisions?(_revisions), do: {:error, :invalid_graph_revisions}

  defp grant_keys do
    MapSet.new([:grant_ref, :delegation_ref, :obligations, :graph_revisions])
  end

  defp clearance_rank(:public), do: 1
  defp clearance_rank(:internal), do: 2
  defp clearance_rank(:confidential), do: 3
  defp clearance_rank(:secret_reference), do: 4

  defp classification_rank(:public), do: 1
  defp classification_rank(:internal), do: 2
  defp classification_rank(:confidential), do: 3
  defp classification_rank(:secret_reference), do: 4
  defp classification_rank(:audit), do: 4
  defp classification_rank(:personal), do: 4

  defp assurance_rank(:baseline), do: 1
  defp assurance_rank(:phishing_resistant), do: 2
  defp assurance_rank(:action_bound_step_up), do: 3

  defp reference(prefix) do
    prefix <> "_" <> Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
  end
end
