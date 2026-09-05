defmodule JidoCode.Identity.Phase01IdentityAuthorityIntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Identity.Administration
  alias JidoCode.Identity.AuthorityBuilder
  alias JidoCode.Identity.RoutePolicy
  alias JidoCode.Identity.Store

  @now ~U[2026-09-05 15:00:00Z]
  @credential "correct horse battery staple"
  @admin %{
    source: :governed_identity_admin,
    actor_ref: "human_identity_administrator",
    assurance: :action_bound_step_up
  }
  @roles [
    :observer,
    :project_developer,
    :project_maintainer,
    :independent_verifier,
    :factory_operator,
    :security_auditor,
    :factory_administrator,
    :knowledge_steward,
    :cost_observer
  ]
  @areas [:developer, :reviewer, :operations, :security, :cost, :knowledge, :administration]
  @area_operations %{
    developer: :factory_shell,
    reviewer: :evidence_page,
    operations: :operations_page,
    security: :security_page,
    cost: :cost_page,
    knowledge: :knowledge_page,
    administration: :administration_page
  }
  @reauthorization_points [
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
  ]

  test "all role explanations and restricted route groups still require exact adapter grants" do
    {store, account} = start_store(roles: @roles, route_groups: @areas)
    session = sign_in(store, account.login)

    Enum.each(@area_operations, fn {area, operation} ->
      assert {:ok, authorization} =
               build(store, session, request!(operation, area, :page, :factory))

      assert authorization.decision == :allowed
      assert authorization.membership_explanations == Enum.sort(@roles)
      assert authorization.exact_grant_ref =~ "/#{operation}"
    end)

    assert RoutePolicy.explained_areas(:observer) == [:developer]
    assert RoutePolicy.explained_areas(:project_maintainer) == [:developer, :reviewer]
    assert RoutePolicy.explained_areas(:factory_administrator) == [:administration]

    assert {:ok, snapshot} = Store.authorization_snapshot(store, account.subject_ref, now: @now)
    [membership] = snapshot.memberships

    assert {:ok, _updated} =
             put_membership(store, membership, roles: @roles, route_groups: [:developer])

    Enum.each(Map.delete(@area_operations, :developer), fn {area, operation} ->
      assert {:ok, authorization} =
               build(store, session, request!(operation, area, :page, :factory))

      assert authorization.decision == :concealed_not_found
      assert authorization.exact_grant_ref == nil
    end)
  end

  test "keeps every resource kind distinct and conceals cross-tenant and cross-project probes" do
    {store, account} = start_store()
    session = sign_in(store, account.login)
    alpha_factory = factory(store)
    alpha_resources = resource_tree(store, alpha_factory, "tenant_alpha", "project_alpha")
    beta_resources = resource_tree(store, alpha_factory, "tenant_alpha", "project_beta")
    other_factory = register_factory(store, "tenant_other")

    assert {:ok, _membership} =
             put_project_membership(store, account.subject_ref, "tenant_alpha", "project_alpha")

    Enum.each(alpha_resources, fn resource ->
      assert {:ok, authorization} =
               build(
                 store,
                 session,
                 request!(:project_page, :developer, :page, resource.resource_ref)
               )

      assert authorization.decision == :allowed
      assert authorization.current_scope.resource_kind == resource.kind
      assert authorization.current_scope.resource_ref == resource.resource_ref
      assert authorization.current_scope.project_ref == "project_alpha"
    end)

    Enum.each(beta_resources, fn resource ->
      assert {:ok, authorization} =
               build(
                 store,
                 session,
                 request!(:project_page, :developer, :page, resource.resource_ref)
               )

      assert authorization.decision == :concealed_not_found
      assert authorization.concealment == :conceal_resource
    end)

    assert {:ok, cross_tenant} =
             build(
               store,
               session,
               request!(:factory_shell, :developer, :page, other_factory.resource_ref)
             )

    assert cross_tenant.decision == :concealed_not_found

    for tampered <- ["resource_unknown", "../project_alpha", "resource_project_alpha%00"] do
      assert {:error, :concealed_not_found} =
               build(store, session, request!(:project_page, :developer, :page, tampered))
    end
  end

  test "covers redaction, step-up, malformed adapters, and unavailable production authority" do
    {store, account} = start_store()
    session = sign_in(store, account.login)

    assert {:ok, redacted} =
             build(store, session, request!(:knowledge_page, :developer, :field, :factory))

    assert redacted.decision == :redacted
    assert redacted.safe_reason == :field_not_available
    assert redacted.redaction == :omit_protected_fields
    assert redacted.exact_grant_ref == nil

    confidential =
      register_resource(store, %{
        resource_ref: "resource_confidential_graph",
        kind: :graph,
        iri: "https://jido.run/id/graph/confidential",
        tenant_ref: "tenant_alpha",
        project_ref: nil,
        parent_ref: factory(store).resource_ref,
        graph_scope_iri: "https://jido.run/graph/confidential",
        classification: :confidential,
        environment: :test,
        lifecycle: :active
      })

    {:ok, snapshot} = Store.authorization_snapshot(store, account.subject_ref, now: @now)
    [membership] = snapshot.memberships

    assert {:ok, _cleared} =
             Administration.put_membership(
               @admin,
               %{
                 membership_ref: membership.membership_ref,
                 subject_ref: membership.subject_ref,
                 tenant_ref: membership.tenant_ref,
                 project_ref: membership.project_ref,
                 roles: membership.roles,
                 route_groups: membership.route_groups,
                 clearance: :confidential,
                 valid_from: membership.valid_from,
                 valid_to: membership.valid_to
               },
               server: store,
               now: @now
             )

    assert {:ok, stronger_assurance} =
             build(
               store,
               session,
               request!(:knowledge_page, :developer, :query, confidential.resource_ref)
             )

    assert stronger_assurance.decision == :step_up_required

    assert {:ok, command_step_up} =
             build(store, session, request!(:project_page, :developer, :command, :factory))

    assert command_step_up.decision == :step_up_required

    {:ok, authentication} = Store.authenticate(store, account.login, @credential, now: @now)

    assert {:error, :authentication_stale} =
             Store.issue_session(store, %{authentication | assurance: :action_bound_step_up},
               now: @now
             )

    for adapter <- [
          JidoCode.Identity.Authority.Unconfigured,
          JidoCode.TestSupport.MalformedHumanAuthorityAdapter,
          JidoCode.TestSupport.CrashingHumanAuthorityAdapter
        ] do
      {adapter_store, adapter_account} = start_store(authority_adapter: adapter)
      adapter_session = sign_in(adapter_store, adapter_account.login)

      assert {:ok, unavailable} =
               build(
                 adapter_store,
                 adapter_session,
                 request!(:factory_shell, :developer, :page, :factory)
               )

      assert unavailable.decision == :unavailable
      assert unavailable.safe_reason == :authority_evidence_unavailable
      assert unavailable.exact_grant_ref == nil
    end
  end

  test "requires current exact delegation and membership across expiry and revocation" do
    {store, issuer} =
      start_store(authority_adapter: JidoCode.TestSupport.DelegationRequiredHumanAuthorityAdapter)

    delegate = enroll(store, "Grace Hopper", "grace@example.test")
    project = register_project(store, factory(store), "tenant_alpha", "project_alpha")

    assert {:ok, membership} =
             put_project_membership(
               store,
               delegate.subject_ref,
               "tenant_alpha",
               "project_alpha",
               valid_to: DateTime.add(@now, 120, :second)
             )

    delegation =
      put_delegation!(store, issuer.subject_ref, delegate.subject_ref, project.resource_ref,
        delegation_ref: "delegation_current",
        valid_to: DateTime.add(@now, 60, :second)
      )

    session = sign_in(store, delegate.login)
    request = request!(:project_page, :developer, :page, project.resource_ref)

    assert {:ok, allowed} = build(store, session, request)
    assert allowed.decision == :allowed
    assert allowed.delegation_ref == delegation.delegation_ref

    assert {:ok, expired_delegation} = build(store, session, request, now: plus(61))
    assert expired_delegation.decision == :denied

    replacement =
      put_delegation!(store, issuer.subject_ref, delegate.subject_ref, project.resource_ref,
        delegation_ref: "delegation_replacement",
        valid_to: DateTime.add(@now, 110, :second)
      )

    assert {:ok, replacement_allowed} = build(store, session, request, now: plus(62))
    assert replacement_allowed.decision == :allowed
    assert replacement_allowed.delegation_ref == replacement.delegation_ref

    assert {:ok, _revoked} =
             Administration.revoke_delegation(@admin, replacement.delegation_ref,
               server: store,
               now: plus(63)
             )

    assert {:ok, revoked_delegation} = build(store, session, request, now: plus(64))
    assert revoked_delegation.decision == :denied

    assert {:ok, _revoked_membership} =
             Administration.revoke_membership(@admin, membership.membership_ref,
               server: store,
               now: plus(65)
             )

    assert {:ok, revoked_membership} = build(store, session, request, now: plus(66))
    assert revoked_membership.decision == :concealed_not_found
  end

  test "reauthorizes every enforcement point and observes current role generations" do
    {store, account} = start_store()
    session = sign_in(store, account.login)
    request = request!(:factory_shell, :developer, :page, :factory)
    assert {:ok, initial} = build(store, session, request)
    assert initial.decision == :allowed

    Enum.each(@reauthorization_points, fn point ->
      assert {:ok, current} =
               AuthorityBuilder.reauthorize(initial, request, point,
                 server: store,
                 now: @now,
                 touch: false
               )

      assert current.decision == :allowed
    end)

    assert {:ok, snapshot} = Store.authorization_snapshot(store, account.subject_ref, now: @now)
    [membership] = snapshot.memberships

    assert {:ok, _changed} =
             put_membership(store, membership,
               roles: membership.roles,
               route_groups: [:administration]
             )

    assert {:ok, revoked} =
             AuthorityBuilder.reauthorize(initial, request, :before_query_execution,
               server: store,
               now: @now,
               touch: false
             )

    assert revoked.decision == :concealed_not_found

    refute revoked.current_scope.revocation_generations ==
             initial.current_scope.revocation_generations
  end

  test "isolates users and tabs and terminally rejects stale account generations" do
    {store, ada} = start_store()
    grace = enroll(store, "Grace Hopper", "grace@example.test")
    alpha = register_project(store, factory(store), "tenant_alpha", "project_alpha")
    beta = register_project(store, factory(store), "tenant_alpha", "project_beta")

    assert {:ok, ada_membership} =
             put_project_membership(store, ada.subject_ref, "tenant_alpha", "project_alpha")

    assert {:ok, _grace_membership} =
             put_project_membership(store, grace.subject_ref, "tenant_alpha", "project_beta")

    ada_tabs = [sign_in(store, ada.login), sign_in(store, ada.login)]
    grace_tab = sign_in(store, grace.login)
    alpha_request = request!(:project_page, :developer, :page, alpha.resource_ref)
    beta_request = request!(:project_page, :developer, :page, beta.resource_ref)

    Enum.each(ada_tabs, fn tab ->
      assert {:ok, %{decision: :allowed}} = build(store, tab, alpha_request)
      assert {:ok, %{decision: :concealed_not_found}} = build(store, tab, beta_request)
    end)

    assert {:ok, %{decision: :allowed}} = build(store, grace_tab, beta_request)
    assert {:ok, %{decision: :concealed_not_found}} = build(store, grace_tab, alpha_request)

    tasks =
      Enum.map(1..20, fn _index ->
        Task.async(fn -> build(store, Enum.random(ada_tabs), alpha_request) end)
      end)

    assert {:ok, _revoked} =
             Administration.revoke_membership(@admin, ada_membership.membership_ref,
               server: store,
               now: @now
             )

    results = Task.await_many(tasks)

    assert Enum.all?(results, fn
             {:ok, %{decision: decision}}
             when decision in [:allowed, :revoked, :concealed_not_found] ->
               true

             _other ->
               false
           end)

    Enum.each(ada_tabs, fn tab ->
      assert {:ok, %{decision: :concealed_not_found}} = build(store, tab, alpha_request)
    end)

    assert {:ok, next_account} =
             Store.logout_all(store, %{actor_ref: ada.subject_ref}, ada.subject_ref, now: @now)

    assert next_account.account_generation == ada.account_generation + 1

    Enum.each(ada_tabs, fn tab ->
      assert {:error, :revoked} = build(store, tab, request!(:factory_shell, :developer, :page))
    end)

    assert {:ok, %{decision: :allowed}} = build(store, grace_tab, beta_request)
  end

  test "rejects immutable reference rebinding and ambiguous current evidence" do
    {store, account} = start_store()
    session = sign_in(store, account.login)
    original_factory = factory(store)
    _other_factory = register_factory(store, "tenant_other")

    assert {:error, :resource_binding_immutable} =
             Administration.register_resource(
               @admin,
               %{
                 resource_ref: original_factory.resource_ref,
                 kind: :graph,
                 iri: "https://jido.run/id/graph/rebound",
                 tenant_ref: "tenant_alpha",
                 project_ref: nil,
                 parent_ref: original_factory.resource_ref,
                 graph_scope_iri: "https://jido.run/graph/rebound",
                 classification: :internal,
                 environment: :test,
                 lifecycle: :active
               },
               server: store,
               now: @now
             )

    assert {:ok, snapshot} = Store.authorization_snapshot(store, account.subject_ref, now: @now)
    [membership] = snapshot.memberships

    assert {:error, :membership_binding_immutable} =
             Administration.put_membership(
               @admin,
               %{
                 membership_ref: membership.membership_ref,
                 subject_ref: account.subject_ref,
                 tenant_ref: "tenant_other",
                 project_ref: nil,
                 roles: membership.roles,
                 route_groups: membership.route_groups,
                 clearance: membership.clearance
               },
               server: store,
               now: @now
             )

    assert {:ok, _duplicate} =
             Administration.put_membership(
               @admin,
               %{
                 subject_ref: account.subject_ref,
                 tenant_ref: membership.tenant_ref,
                 project_ref: nil,
                 roles: membership.roles,
                 route_groups: membership.route_groups,
                 clearance: membership.clearance
               },
               server: store,
               now: @now
             )

    assert {:ok, ambiguous} =
             build(store, session, request!(:factory_shell, :developer, :page, :factory))

    assert ambiguous.decision == :denied
    assert ambiguous.exact_grant_ref == nil
  end

  defp start_store(options \\ []) do
    {identity_options, bootstrap_options} =
      Keyword.split(options, [:authority_adapter])

    config =
      Keyword.merge(
        [
          enabled: true,
          persistence: false,
          policy_revision: "hui.identity.test.v1",
          pbkdf2_iterations: 1_000,
          max_failed_attempts: 5,
          lockout_seconds: 300,
          hard_lifetime_seconds: 600,
          idle_lifetime_seconds: 600,
          idle_warning_seconds: 30,
          maximum_authentication_age_seconds: 600,
          bootstrap: nil,
          authority_adapter: JidoCode.TestSupport.StaticHumanAuthorityAdapter
        ],
        identity_options
      )

    store =
      start_supervised!(%{
        id: {Store, make_ref()},
        start: {Store, :start_link, [[name: nil, config: config]]}
      })

    {:ok, account} =
      Store.bootstrap(
        store,
        %{
          display_name: "Ada Lovelace",
          login: unique_login("ada"),
          tenant_ref: "tenant_alpha",
          roles: Keyword.get(bootstrap_options, :roles, [:observer]),
          route_groups: Keyword.get(bootstrap_options, :route_groups, [:developer])
        },
        @credential,
        local_ceremony: true,
        now: @now
      )

    {store, account}
  end

  defp sign_in(store, login) do
    {:ok, authentication} = Store.authenticate(store, login, @credential, now: @now)
    {:ok, session} = Store.issue_session(store, authentication, now: @now)
    session
  end

  defp enroll(store, display_name, login) do
    {:ok, account} =
      Administration.enroll_account(
        @admin,
        %{display_name: display_name, login: unique_login(login)},
        @credential,
        server: store,
        now: @now
      )

    account
  end

  defp unique_login(prefix) do
    local = prefix |> String.split("@") |> List.first()
    "#{local}.#{System.unique_integer([:positive])}@example.test"
  end

  defp put_membership(store, membership, options) do
    Administration.put_membership(
      @admin,
      %{
        membership_ref: membership.membership_ref,
        subject_ref: membership.subject_ref,
        tenant_ref: membership.tenant_ref,
        project_ref: membership.project_ref,
        roles: Keyword.fetch!(options, :roles),
        route_groups: Keyword.fetch!(options, :route_groups),
        clearance: membership.clearance,
        valid_from: membership.valid_from,
        valid_to: membership.valid_to
      },
      server: store,
      now: @now
    )
  end

  defp put_project_membership(store, subject_ref, tenant_ref, project_ref, options \\ []) do
    Administration.put_membership(
      @admin,
      %{
        subject_ref: subject_ref,
        tenant_ref: tenant_ref,
        project_ref: project_ref,
        roles: [:project_developer],
        route_groups: [:developer],
        clearance: :internal,
        valid_from: @now,
        valid_to: Keyword.get(options, :valid_to, ~U[9999-12-31 23:59:59Z])
      },
      server: store,
      now: @now
    )
  end

  defp put_delegation!(store, issuer_ref, delegate_ref, resource_ref, options) do
    {:ok, delegation} =
      Administration.put_delegation(
        @admin,
        %{
          delegation_ref: Keyword.fetch!(options, :delegation_ref),
          issuer_subject_ref: issuer_ref,
          delegate_subject_ref: delegate_ref,
          resource_refs: [resource_ref],
          actions: [:page],
          graph_families: [:project],
          environment: :test,
          valid_from: @now,
          valid_to: Keyword.fetch!(options, :valid_to),
          attenuation_parent_ref: nil,
          minimum_assurance: :baseline,
          maximum_classification: :internal,
          obligations: [:record_decision]
        },
        server: store,
        now: @now
      )

    delegation
  end

  defp resource_tree(store, parent, tenant_ref, project_ref) do
    project = register_project(store, parent, tenant_ref, project_ref)
    attempt = register_child(store, :attempt, project, "#{project_ref}_attempt")
    interaction = register_child(store, :interaction_session, attempt, "#{project_ref}_session")
    candidate = register_child(store, :candidate, attempt, "#{project_ref}_candidate")
    preview = register_child(store, :wiki_preview, project, "#{project_ref}_preview")
    graph = register_child(store, :graph, project, "#{project_ref}_graph")
    [project, attempt, interaction, candidate, preview, graph]
  end

  defp register_factory(store, tenant_ref) do
    register_resource(store, %{
      resource_ref: "resource_factory_#{tenant_ref}",
      kind: :factory,
      iri: "https://jido.run/id/factory/#{tenant_ref}",
      tenant_ref: tenant_ref,
      project_ref: nil,
      parent_ref: nil,
      graph_scope_iri: "https://jido.run/graph/factory/#{tenant_ref}",
      classification: :internal,
      environment: :test,
      lifecycle: :active
    })
  end

  defp register_project(store, parent, tenant_ref, project_ref) do
    register_resource(store, %{
      resource_ref: "resource_#{project_ref}",
      kind: :project,
      iri: "https://jido.run/id/project/#{project_ref}",
      tenant_ref: tenant_ref,
      project_ref: project_ref,
      parent_ref: parent.resource_ref,
      graph_scope_iri: "https://jido.run/graph/project/#{project_ref}",
      classification: :internal,
      environment: :test,
      lifecycle: :active
    })
  end

  defp register_child(store, kind, parent, suffix) do
    register_resource(store, %{
      resource_ref: "resource_#{suffix}",
      kind: kind,
      iri: "https://jido.run/id/#{kind}/#{suffix}",
      tenant_ref: parent.tenant_ref,
      project_ref: parent.project_ref,
      parent_ref: parent.resource_ref,
      graph_scope_iri: "https://jido.run/graph/#{kind}/#{suffix}",
      classification: :internal,
      environment: :test,
      lifecycle: :active
    })
  end

  defp register_resource(store, attributes) do
    {:ok, resource} =
      Administration.register_resource(@admin, attributes, server: store, now: @now)

    resource
  end

  defp factory(store) do
    {:ok, resource} = Store.resolve_resource(store, :factory)
    resource
  end

  defp request!(operation, area, action, resource_ref \\ :factory) do
    {:ok, request} =
      AuthorityBuilder.request(operation, area, action, resource_ref,
        correlation_ref: "phase-01-integration"
      )

    request
  end

  defp build(store, session, request, options \\ []) do
    AuthorityBuilder.build(
      session.session_ref,
      request,
      Keyword.merge([server: store, now: @now, touch: false], options)
    )
  end

  defp plus(seconds), do: DateTime.add(@now, seconds, :second)
end
