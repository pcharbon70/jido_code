defmodule JidoCode.Identity.AuthorityFoundationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Identity.Administration
  alias JidoCode.Identity.AuthorityBuilder
  alias JidoCode.Identity.AuthorityRequest
  alias JidoCode.Identity.Revocations
  alias JidoCode.Identity.Store

  @now ~U[2026-09-05 12:00:00Z]
  @credential "correct horse battery staple"
  @admin_context %{
    source: :governed_identity_admin,
    actor_ref: "human_identity_administrator",
    assurance: :action_bound_step_up
  }

  test "constructs one exact named-human factory scope from current server authority" do
    {store, account, session} = start_human_session()
    request = request!(:factory_shell, :developer, :page, :factory)

    assert {:ok, authorization} = build(store, session, request)
    assert authorization.decision == :allowed
    assert authorization.product_identity.display_name == "Ada Lovelace"
    assert authorization.product_identity.subject_ref == account.subject_ref

    assert authorization.product_identity.actor_iri ==
             authorization.product_identity.principal_iri

    assert authorization.authority_context.actor_iri == authorization.product_identity.actor_iri
    assert authorization.current_scope.subject_ref == account.subject_ref
    assert authorization.current_scope.tenant_ref == "tenant_alpha"
    assert authorization.current_scope.project_ref == nil
    assert authorization.current_scope.principal_class == :human
    assert authorization.membership_explanations == [:observer]
    assert authorization.exact_grant_ref =~ "https://jido.run/id/grant/test/"
    refute Map.has_key?(authorization.current_scope, :roles)
    refute Map.has_key?(authorization.current_scope, :grants)
  end

  test "treats role labels as explanation and denies absent route membership" do
    {store, account, session} = start_human_session()
    {:ok, snapshot} = Store.authorization_snapshot(store, account.subject_ref, now: @now)
    [membership] = snapshot.memberships

    assert {:ok, updated} =
             Administration.put_membership(
               @admin_context,
               %{
                 membership_ref: membership.membership_ref,
                 subject_ref: account.subject_ref,
                 tenant_ref: membership.tenant_ref,
                 project_ref: nil,
                 roles: [:observer],
                 route_groups: [:administration],
                 clearance: :internal
               },
               server: store,
               now: @now
             )

    assert updated.roles == [:observer]

    assert {:ok, authorization} =
             build(store, session, request!(:factory_shell, :developer, :page, :factory))

    assert authorization.decision == :concealed_not_found
    assert authorization.exact_grant_ref == nil
  end

  test "keeps copied cross-project resource references concealed" do
    {store, account, session} = start_human_session()
    factory_ref = factory_ref(store)
    alpha = register_project(store, factory_ref, "project_alpha")
    beta = register_project(store, factory_ref, "project_beta")

    assert {:ok, _membership} =
             Administration.put_membership(
               @admin_context,
               %{
                 subject_ref: account.subject_ref,
                 tenant_ref: "tenant_alpha",
                 project_ref: "project_alpha",
                 roles: [:project_developer],
                 route_groups: [:developer],
                 clearance: :internal
               },
               server: store,
               now: @now
             )

    assert {:ok, allowed} =
             build(store, session, request!(:project_page, :developer, :page, alpha.resource_ref))

    assert allowed.decision == :allowed
    assert allowed.current_scope.project_ref == "project_alpha"

    assert {:ok, concealed} =
             build(store, session, request!(:project_page, :developer, :page, beta.resource_ref))

    assert concealed.decision == :concealed_not_found
    assert concealed.concealment == :conceal_resource

    assert {:error, :concealed_not_found} =
             build(
               store,
               session,
               request!(:project_page, :developer, :page, "resource_unknown")
             )
  end

  test "enrolls independent humans and applies delegation expiry and revocation immediately" do
    {store, issuer, _issuer_session} = start_human_session()
    delegate = enroll(store, "Grace Hopper", "grace@example.test")
    resource = register_project(store, factory_ref(store), "project_alpha")

    assert {:ok, _membership} =
             Administration.put_membership(
               @admin_context,
               %{
                 subject_ref: delegate.subject_ref,
                 tenant_ref: "tenant_alpha",
                 project_ref: "project_alpha",
                 roles: [:project_developer],
                 route_groups: [:developer],
                 clearance: :internal
               },
               server: store,
               now: @now
             )

    delegation_attributes = %{
      delegation_ref: "delegation_alpha",
      issuer_subject_ref: issuer.subject_ref,
      delegate_subject_ref: delegate.subject_ref,
      resource_refs: [resource.resource_ref],
      actions: [:page],
      graph_families: [:project],
      environment: :test,
      valid_from: @now,
      valid_to: DateTime.add(@now, 300, :second),
      attenuation_parent_ref: nil,
      minimum_assurance: :baseline,
      maximum_classification: :internal,
      obligations: [:record_decision]
    }

    assert {:ok, delegation} =
             Administration.put_delegation(@admin_context, delegation_attributes,
               server: store,
               now: @now
             )

    assert delegation.policy_revision == "hui.identity.test.v1"
    delegate_session = authenticate_and_issue(store, delegate.login, @now)
    request = request!(:project_page, :developer, :page, resource.resource_ref)

    assert {:ok, current} = build(store, delegate_session, request)
    assert current.decision == :allowed
    assert current.delegation_ref == delegation.delegation_ref

    assert {:ok, expired} =
             AuthorityBuilder.build(delegate_session.session_ref, request,
               server: store,
               now: DateTime.add(@now, 301, :second),
               touch: false
             )

    assert expired.decision == :allowed
    assert expired.delegation_ref == nil

    assert {:ok, _revoked} =
             Administration.revoke_delegation(@admin_context, delegation.delegation_ref,
               server: store,
               now: DateTime.add(@now, 1, :second)
             )

    assert {:ok, after_revocation} = build(store, delegate_session, request)
    assert after_revocation.decision == :allowed
    assert after_revocation.delegation_ref == nil
  end

  test "rejects widened attenuation and browser-injected authority fields" do
    {store, issuer, _session} = start_human_session()
    delegate = enroll(store, "Grace Hopper", "grace@example.test")
    beneficiary = enroll(store, "Katherine Johnson", "katherine@example.test")
    resource = register_project(store, factory_ref(store), "project_alpha")

    parent = %{
      delegation_ref: "delegation_parent",
      issuer_subject_ref: issuer.subject_ref,
      delegate_subject_ref: delegate.subject_ref,
      resource_refs: [resource.resource_ref],
      actions: [:page],
      graph_families: [:project],
      environment: :test,
      valid_from: @now,
      valid_to: DateTime.add(@now, 300, :second),
      attenuation_parent_ref: nil,
      minimum_assurance: :baseline,
      maximum_classification: :internal,
      obligations: [:record_decision]
    }

    assert {:ok, _parent} =
             Administration.put_delegation(@admin_context, parent,
               server: store,
               now: @now
             )

    widened = %{
      parent
      | delegation_ref: "delegation_child",
        issuer_subject_ref: delegate.subject_ref,
        delegate_subject_ref: beneficiary.subject_ref,
        actions: [:page, :query],
        attenuation_parent_ref: "delegation_parent"
    }

    assert {:error, :delegation_widened} =
             Administration.put_delegation(@admin_context, widened,
               server: store,
               now: @now
             )

    assert {:error, :invalid_authority_request} =
             AuthorityRequest.new(%{
               operation: :project_page,
               area: :developer,
               action: :page,
               resource_ref: resource.resource_ref,
               reauthorization_point: :before_response_start,
               correlation_ref: "hostile-request",
               actor_iri: "https://attacker.invalid/human/admin",
               roles: [:factory_administrator]
             })
  end

  test "publishes monotonic revocation generations and fails closed on stale transitions" do
    {store, account, session} = start_human_session()
    :ok = Revocations.subscribe()
    {:ok, snapshot} = Store.authorization_snapshot(store, account.subject_ref, now: @now)
    [membership] = snapshot.memberships

    assert {:ok, _updated} =
             Administration.put_membership(
               @admin_context,
               %{
                 membership_ref: membership.membership_ref,
                 subject_ref: account.subject_ref,
                 tenant_ref: membership.tenant_ref,
                 project_ref: nil,
                 roles: membership.roles,
                 route_groups: [:administration],
                 clearance: membership.clearance
               },
               server: store,
               now: @now
             )

    assert_receive {:identity_revoked, %{dimension: :role, subject_ref: subject_ref}}
    assert subject_ref == account.subject_ref

    assert {:ok, denied} =
             build(store, session, request!(:factory_shell, :developer, :page, :factory))

    assert denied.decision == :concealed_not_found

    assert {:ok, event} =
             Administration.publish_generation(
               @admin_context,
               %{
                 dimension: :graph,
                 prior_generation: snapshot.generations.graph,
                 next_generation: snapshot.generations.graph + 1,
                 resource_ref: factory_ref(store),
                 subject_ref: nil
               },
               server: store,
               now: @now
             )

    assert event.next_generation == event.prior_generation + 1
    assert_receive {:identity_revoked, %{dimension: :graph, next_generation: next_generation}}
    assert next_generation == event.next_generation

    assert {:error, :invalid_generation_transition} =
             Administration.publish_generation(
               @admin_context,
               %{
                 dimension: :graph,
                 prior_generation: snapshot.generations.graph,
                 next_generation: snapshot.generations.graph + 1
               },
               server: store,
               now: @now
             )
  end

  test "makes missing production graph authority explicitly unavailable" do
    {store, _account, session} =
      start_human_session(authority_adapter: JidoCode.Identity.Authority.Unconfigured)

    assert {:ok, authorization} =
             build(store, session, request!(:factory_shell, :developer, :page, :factory))

    assert authorization.decision == :unavailable
    assert authorization.exact_grant_ref == nil
  end

  defp start_human_session(overrides \\ []) do
    store = start_store(overrides)

    {:ok, account} =
      Store.bootstrap(
        store,
        %{
          display_name: "Ada Lovelace",
          login: "ada@example.test",
          tenant_ref: "tenant_alpha",
          roles: [:observer],
          route_groups: [:developer]
        },
        @credential,
        local_ceremony: true,
        now: @now
      )

    {store, account, authenticate_and_issue(store, account.login, @now)}
  end

  defp start_store(overrides) do
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
        overrides
      )

    start_supervised!({Store, name: nil, config: config})
  end

  defp authenticate_and_issue(store, login, now) do
    {:ok, authentication} = Store.authenticate(store, login, @credential, now: now)
    {:ok, session} = Store.issue_session(store, authentication, now: now)
    session
  end

  defp enroll(store, display_name, login) do
    {:ok, account} =
      Administration.enroll_account(
        @admin_context,
        %{display_name: display_name, login: login},
        @credential,
        server: store,
        now: @now
      )

    account
  end

  defp register_project(store, parent_ref, project_ref) do
    {:ok, resource} =
      Administration.register_resource(
        @admin_context,
        %{
          resource_ref: "resource_#{project_ref}",
          kind: :project,
          iri: "https://jido.run/id/project/#{project_ref}",
          tenant_ref: "tenant_alpha",
          project_ref: project_ref,
          parent_ref: parent_ref,
          graph_scope_iri: "https://jido.run/graph/project/#{project_ref}",
          classification: :internal,
          environment: :test,
          lifecycle: :active
        },
        server: store,
        now: @now
      )

    resource
  end

  defp factory_ref(store) do
    {:ok, resource} = Store.resolve_resource(store, :factory)
    resource.resource_ref
  end

  defp request!(operation, area, action, resource_ref) do
    {:ok, request} =
      AuthorityBuilder.request(operation, area, action, resource_ref,
        correlation_ref: "authority-foundation-test"
      )

    request
  end

  defp build(store, session, request) do
    AuthorityBuilder.build(session.session_ref, request,
      server: store,
      now: @now,
      touch: false
    )
  end
end
