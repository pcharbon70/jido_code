defmodule JidoCodeWeb.ProductRoutePhaseC3Test do
  use JidoCodeWeb.ConnCase, async: false

  alias JidoCode.Identity.Administration
  alias JidoCode.Identity.Store

  @admin %{
    source: :governed_identity_admin,
    actor_ref: "human_phase_c3_administrator",
    assurance: :action_bound_step_up
  }

  setup_all do
    now = DateTime.utc_now()
    {:ok, factory} = Store.resolve_resource(:factory)

    project =
      register_resource!(%{
        resource_ref: "project_phase_c3",
        kind: :project,
        iri: "https://jido.run/id/project/phase-c3",
        tenant_ref: factory.tenant_ref,
        project_ref: "phase_c3",
        parent_ref: factory.resource_ref,
        graph_scope_iri: "https://jido.run/graph/project/phase-c3",
        classification: :internal,
        environment: :test,
        lifecycle: :active
      })

    attempt = child!(:attempt, "attempt_phase_c3", project)
    candidate = child!(:candidate, "candidate_phase_c3", attempt)

    {:ok, _membership} =
      Administration.put_membership(
        @admin,
        %{
          membership_ref: "membership_phase_c3",
          subject_ref: "human_test_operator",
          tenant_ref: project.tenant_ref,
          project_ref: project.project_ref,
          roles: [
            :project_developer,
            :project_maintainer,
            :independent_verifier,
            :knowledge_steward
          ],
          route_groups: [:developer, :reviewer, :knowledge],
          clearance: :internal,
          valid_from: DateTime.add(now, -60),
          valid_to: DateTime.add(now, 86_400)
        },
        now: now
      )

    %{project: project, attempt: attempt, candidate: candidate}
  end

  test "owns every factory and restricted route with an explicit controller page" do
    for path <- [
          "/factory",
          "/factory/fleet",
          "/projects",
          "/operations",
          "/operations/costs",
          "/security",
          "/security/incidents",
          "/governance",
          "/account",
          "/account/sessions"
        ] do
      response = authenticated_conn() |> get(path)
      document = response |> html_response(200) |> LazyHTML.from_document()
      assert has_selector?(document, "[data-product-route]")
      assert has_selector?(document, "#product-main")
      assert get_resp_header(response, "cache-control") == ["no-store, private"]
      assert get_resp_header(response, "referrer-policy") == ["origin"]
    end
  end

  test "authorizes project, attempt, candidate, and closed knowledge identities independently",
       context do
    %{project: project, attempt: attempt, candidate: candidate} = context

    paths = [
      "/projects/#{project.resource_ref}",
      "/projects/#{project.resource_ref}/attempts",
      "/projects/#{project.resource_ref}/wiki",
      "/projects/#{project.resource_ref}/dependencies",
      "/projects/#{project.resource_ref}/attempts/#{attempt.resource_ref}",
      "/projects/#{project.resource_ref}/knowledge/security",
      "/reviews/#{candidate.resource_ref}"
    ]

    for path <- paths do
      response = authenticated_conn() |> get(path)
      assert response.status == 200
      assert response.assigns.authorization.decision == :allowed
    end

    concealed =
      authenticated_conn()
      |> get("/projects/#{project.resource_ref}/attempts/unknown_attempt")

    invalid_lens =
      authenticated_conn()
      |> get("/projects/#{project.resource_ref}/knowledge/arbitrary")

    assert response(concealed, 404) == "Not found."
    assert response(invalid_lens, 404) == "Not found."
  end

  test "normalizes product trailing slashes and rejects malformed or unbounded refs" do
    redirected = authenticated_conn() |> get("/factory/?q=waiting")
    assert redirected.status == 308
    assert get_resp_header(redirected, "location") == ["/factory?q=waiting"]

    for ref <- ["contains.dot", "contains%20space", String.duplicate("a", 65)] do
      rejected = authenticated_conn() |> get("/projects/#{ref}")
      assert response(rejected, 404) == "Not found."
    end
  end

  test "preserves a safe deep link through named-human authentication", %{project: project} do
    path = "/projects/#{project.resource_ref}/attempts?q=waiting&page=2"
    anonymous = get(build_conn(), path)

    assert redirected_to(anonymous) == "/sign-in?" <> URI.encode_query(%{"return_to" => path})

    authenticated =
      anonymous
      |> recycle()
      |> with_same_origin()
      |> post(~p"/sign-in",
        session: %{
          login: "operator@example.test",
          credential: "test-named-human-credential",
          return_to: path
        }
      )

    assert redirected_to(authenticated) == path
  end

  defp child!(kind, ref, parent) do
    register_resource!(%{
      resource_ref: ref,
      kind: kind,
      iri: "https://jido.run/id/#{kind}/#{ref}",
      tenant_ref: parent.tenant_ref,
      project_ref: parent.project_ref,
      parent_ref: parent.resource_ref,
      graph_scope_iri: "https://jido.run/graph/#{kind}/#{ref}",
      classification: :internal,
      environment: :test,
      lifecycle: :active
    })
  end

  defp register_resource!(attributes) do
    {:ok, resource} = Administration.register_resource(@admin, attributes)
    resource
  end

  defp authenticated_conn do
    build_conn()
    |> init_test_session(%{})
    |> sign_in_named_human()
  end

  defp has_selector?(document, selector),
    do: document |> LazyHTML.query(selector) |> LazyHTML.to_html() != ""
end
