# Real production identity and semantic-command corpus, disposable instance only.
fn base, credential ->
  alias JidoCode.Identity.{Administration, Store}
  alias JidoCode.Knowledge.{GraphRegistry, QueryRunner, ResourceIdentity, StoreServer, Writer}
  alias JidoCode.Knowledge.Repositories.{Enrollment, Locator}

  {:ok, authentication} = JidoCode.Identity.authenticate("local-proof@example.test", credential)
  subject = authentication.subject_ref
  human = "https://jido.run/id/human/#{subject}"
  {:ok, factory} = Store.resolve_resource(:factory)
  surface = Application.fetch_env!(:jido_code, :product_surface)

  admin = %{
    source: :governed_identity_admin,
    actor_ref: subject,
    assurance: :action_bound_step_up
  }

  commits =
    for label <- ["alpha", "beta", "hidden"] do
      {:ok, repository} = ResourceIdentity.conceptual_repository("d4-#{label}")
      {:ok, scope} = ResourceIdentity.scope(:repository, repository)

      {:ok, resource} =
        Administration.register_resource(admin, %{
          resource_ref: "d4_#{label}",
          kind: :project,
          iri: repository,
          tenant_ref: factory.tenant_ref,
          project_ref: "d4_#{label}",
          parent_ref: factory.resource_ref,
          graph_scope_iri: scope
        })

      if label != "hidden" do
        {:ok, _} =
          Administration.put_membership(admin, %{
            membership_ref: "d4_membership_#{label}",
            subject_ref: subject,
            tenant_ref: factory.tenant_ref,
            project_ref: resource.project_ref,
            roles: [:observer],
            route_groups: [:developer],
            clearance: :internal
          })
      end

      now = DateTime.utc_now()
      {:ok, command_iri} = ResourceIdentity.generate_local(:command)
      {:ok, correlation} = ResourceIdentity.generate_local(:activity)

      {:ok, locator} =
        Locator.new(%{
          provider: "https://github.com",
          external_id: "d4-#{label}",
          owner: "fixture",
          name: label,
          state: :active,
          observed_at: now,
          relationships: []
        })

      {:ok, enrollment} =
        Enrollment.new(%{
          factory_iri: surface[:factory_iri],
          repository_iri: repository,
          repository_scope_iri: scope,
          policy_boundary_iri: surface[:policy_boundary_iri],
          policy_iris: surface[:policy_iris],
          locator: locator,
          actor_iri: human,
          cause_iri: command_iri,
          reason: "D4 production scope qualification",
          valid_from: now,
          valid_to: DateTime.add(now, 86_400)
        })

      {:ok, catalog} = GraphRegistry.graph_iri(:factory_catalog, %{})
      {:ok, metadata} = QueryRunner.graph_metadata(catalog)

      {:ok, command} =
        Enrollment.enroll_command(
          enrollment,
          %{
            command_iri: command_iri,
            principal_iri: human,
            factory_scope_iri: surface[:factory_scope_iri],
            idempotency_key: "d4-#{label}",
            correlation_iri: correlation,
            causation_iri: command_iri,
            expected_dataset_revision: StoreServer.summary().dataset_revision,
            catalog_graph_iri: catalog,
            expected_catalog_revision: metadata.graph_revision,
            reason: "D4 production scope qualification"
          },
          clock: fn -> now end
        )

      {:ok, %{outcome: :committed} = receipt} = Writer.execute(command)
      {command, receipt}
    end

  revision = StoreServer.summary().dataset_revision

  {output, 0} =
    System.cmd("node", ["scripts/qualify_hui_d4_scopes.mjs"],
      env: [
        {"HUI_D4_BASE", base},
        {"HUI_D4_LOGIN", "local-proof@example.test"},
        {"HUI_D4_CREDENTIAL", credential},
        {"HUI_D4_REVISION", Integer.to_string(revision)}
      ],
      stderr_to_stdout: true
    )

  IO.write(output)
  ^revision = StoreServer.summary().dataset_revision
  {:ok, commits}
end
