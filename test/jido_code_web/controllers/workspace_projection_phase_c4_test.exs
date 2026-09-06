defmodule JidoCodeWeb.WorkspaceProjectionPhaseC4Test do
  use JidoCodeWeb.ConnCase, async: false

  alias JidoCode.Identity.Administration
  alias JidoCode.Identity.Store
  alias JidoCode.TestSupport.HypermediaUIPhaseC4Fixture

  @admin %{
    source: :governed_identity_admin,
    actor_ref: "human_phase_c4_workspace_administrator",
    assurance: :action_bound_step_up
  }

  setup_all do
    now = DateTime.utc_now()
    {:ok, factory} = Store.resolve_resource(:factory)

    project =
      register_resource!(%{
        resource_ref: "project_phase_c4_workspace",
        kind: :project,
        iri: "https://jido.run/id/project/phase-c4-workspace",
        tenant_ref: factory.tenant_ref,
        project_ref: "phase_c4_workspace",
        parent_ref: factory.resource_ref,
        graph_scope_iri: "https://jido.run/graph/project/phase-c4-workspace",
        classification: :internal,
        environment: :test,
        lifecycle: :active
      })

    attempt =
      register_resource!(%{
        resource_ref: "attempt_phase_c4_workspace",
        kind: :attempt,
        iri: "https://jido.run/id/attempt/phase-c4-workspace",
        tenant_ref: project.tenant_ref,
        project_ref: project.project_ref,
        parent_ref: project.resource_ref,
        graph_scope_iri: project.graph_scope_iri,
        classification: :internal,
        environment: :test,
        lifecycle: :active
      })

    {:ok, _membership} =
      Administration.put_membership(
        @admin,
        %{
          membership_ref: "membership_phase_c4_workspace",
          subject_ref: "human_test_operator",
          tenant_ref: project.tenant_ref,
          project_ref: project.project_ref,
          roles: [:project_developer, :project_maintainer, :independent_verifier],
          route_groups: [:developer, :reviewer],
          clearance: :internal,
          valid_from: DateTime.add(now, -60),
          valid_to: DateTime.add(now, 86_400)
        },
        now: now
      )

    %{project: project, attempt: attempt}
  end

  setup do
    prior_provider = Application.get_env(:jido_code, :product_read_projection_provider)
    prior_fixture = Application.get_env(:jido_code, :read_projection_fixture)
    prior_pid = Application.get_env(:jido_code, :read_projection_test_pid)

    Application.put_env(
      :jido_code,
      :product_read_projection_provider,
      JidoCode.TestSupport.FakeReadProjectionProvider
    )

    Application.put_env(:jido_code, :read_projection_test_pid, self())

    on_exit(fn ->
      restore(:product_read_projection_provider, prior_provider)
      restore(:read_projection_fixture, prior_fixture)
      restore(:read_projection_test_pid, prior_pid)
    end)

    :ok
  end

  test "renders project, attempt, wiki, and dependency projections through stable native pages",
       %{conn: conn, project: project, attempt: attempt} do
    project_map = %{
      label: "alpha <script>",
      resource_ref: project.resource_ref,
      repository_identity: "One conceptual repository",
      project_alias: "Project is a presentation alias for this repository",
      enrollment: "Enrolled",
      desired_state: "1 eligible · 1 blocked",
      current_state: "1 executing · 0 awaiting decision",
      branch_policy: "Protected main; isolated worktree",
      owner: "Project owner",
      evidence: "Independent verification needed",
      wiki: "Manual",
      dependencies: "1 projected",
      budget: "Unavailable; missing observations are not zero",
      cost: "Unavailable; missing observations are not zero",
      provenance: "Reviewed query 2.11.0 at dataset revision 77"
    }

    attempt_row = %{
      label: attempt.resource_ref,
      href: "/projects/#{project.resource_ref}/attempts/#{attempt.resource_ref}",
      task: "Compile",
      lifecycle: "Running",
      fence: "7",
      freshness: "Current query revision",
      owner: "Project owner"
    }

    wiki = %{
      state: "Manual",
      enrollment_revision: "4",
      generation: "On demand",
      current_edition: "Available",
      freshness: "Current enrollment projection",
      cost: "Unavailable; no cost is inferred"
    }

    capabilities = [
      %{key: :read_workspace, label: "Read-only workspace", state: :ready},
      %{key: :cost, label: "Cost and budget", state: :unconfigured},
      %{key: :semantic_controls, label: "Semantic controls", state: :unconfigured}
    ]

    base = %{
      project: project_map,
      attempts: [attempt_row],
      wiki: wiki,
      dependencies: [
        %{label: "Compiler", dependency: "Parser", status: "Observed in exact snapshot"}
      ],
      summaries: %{
        work: %{eligible: 1, blocked: 1, executing: 1, awaiting_decision: 0}
      },
      capabilities: capabilities,
      pagination: %{
        page: 1,
        page_size: 20,
        known_total: 1,
        page_count: 1,
        previous_href: nil,
        next_href: nil,
        summary: "Page 1 of 1; 1 authorized attempt"
      }
    }

    fixtures = %{
      project: HypermediaUIPhaseC4Fixture.projection(:project, base),
      project_attempts: HypermediaUIPhaseC4Fixture.projection(:project_attempts, base),
      project_wiki: HypermediaUIPhaseC4Fixture.projection(:project_wiki, base),
      project_dependencies: HypermediaUIPhaseC4Fixture.projection(:project_dependencies, base)
    }

    Application.put_env(:jido_code, :read_projection_fixture, fixtures)

    routes = [
      {"/projects/#{project.resource_ref}", "#project-overview-identity",
       "One conceptual repository"},
      {"/projects/#{project.resource_ref}/attempts", "#project-attempts-item-1-link",
       attempt.resource_ref},
      {"/projects/#{project.resource_ref}/wiki", "#project-wiki-summary", "Manual"},
      {"/projects/#{project.resource_ref}/dependencies", "#project-dependencies-item-1", "Parser"}
    ]

    for {path, selector, expected} <- routes do
      response = conn |> recycle() |> authenticated() |> get(path)
      html = html_response(response, 200)
      document = LazyHTML.from_document(html)

      assert has?(document, selector, expected)
      assert get_resp_header(response, "cache-control") == ["no-store, private"]
      refute html =~ project.iri
      refute html =~ attempt.iri
      refute html =~ "<script>"
    end
  end

  test "renders an effect-free attempt workspace with explicit semantic distinctions",
       %{conn: conn, project: project, attempt: attempt} do
    projection =
      HypermediaUIPhaseC4Fixture.projection(:attempt, %{
        attempt: %{
          label: attempt.resource_ref,
          project: "phase_c4_workspace",
          task: "Compile",
          agent: "Builder",
          profile: "Trusted profile",
          runtime: "OTP 29",
          owner: "Project owner",
          branch: "codex/read",
          worktree: "isolated",
          revision: "2",
          fence: "7",
          freshness: "Current",
          lifecycle_steps: [
            %{label: "Prepared", state: :complete},
            %{label: "Running", state: :current}
          ],
          outcomes: [
            %{label: "Candidate artifact claimed", state: :observed},
            %{label: "Independent verification pending", state: :pending},
            %{label: "External source application unavailable", state: :unavailable}
          ],
          budget: nil
        },
        summaries: %{
          counts: [
            %{key: :artifacts, label: "Artifacts", value: 1, state: :ready},
            %{
              key: :verification,
              label: "Independent verification",
              value: nil,
              state: :unauthorized
            }
          ],
          recent_items: [
            %{label: "Running", detail: "Observed lifecycle revision 2", kind: :lifecycle}
          ],
          plan_state: "Plan state is separately labeled from observed runtime state",
          evidence_state: "Claims and independent verification remain distinct",
          source_state: "Candidate source is not externally applied source",
          progress_state: "Running does not imply semantic progress"
        },
        capabilities: [
          %{key: :read_workspace, label: "Read-only attempt workspace", state: :ready},
          %{key: :pause, label: "Pause", state: :unconfigured},
          %{key: :stop, label: "Stop", state: :unconfigured},
          %{key: :retry, label: "Retry", state: :unconfigured},
          %{key: :approve, label: "Approve", state: :unconfigured}
        ]
      })

    Application.put_env(:jido_code, :read_projection_fixture, %{attempt: projection})

    response =
      conn
      |> authenticated()
      |> get("/projects/#{project.resource_ref}/attempts/#{attempt.resource_ref}")

    html = html_response(response, 200)
    document = LazyHTML.from_document(html)

    assert has?(document, "#attempt-workspace-summary[data-attempt-summary]", "Running")
    assert has?(document, "#attempt-workspace-counts", "Unavailable")
    assert has?(document, "#attempt-workspace-semantics", "does not imply semantic progress")
    assert has?(document, "#attempt-workspace-capabilities", "Pause")
    refute has?(document, "#attempt-workspace-summary button")
    refute has?(document, "#attempt-workspace-capabilities button")
    refute has?(document, "#attempt-workspace-summary form")
    refute html =~ project.iri
    refute html =~ attempt.iri
  end

  defp authenticated(conn) do
    conn |> init_test_session(%{}) |> sign_in_named_human()
  end

  defp register_resource!(attributes) do
    {:ok, resource} = Administration.register_resource(@admin, attributes)
    resource
  end

  defp has?(document, selector), do: document |> LazyHTML.query(selector) |> Enum.any?()

  defp has?(document, selector, text) do
    document |> LazyHTML.query(selector) |> LazyHTML.text() |> String.contains?(text)
  end

  defp restore(key, nil), do: Application.delete_env(:jido_code, key)
  defp restore(key, value), do: Application.put_env(:jido_code, key, value)
end
