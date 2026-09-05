defmodule JidoCodeWeb.Router do
  use JidoCodeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {JidoCodeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_authenticated_api do
    plug JidoCodeWeb.ProductAuth, :fetch_api_scope
    plug JidoCodeWeb.ProductAuth, :require_authenticated_api
  end

  pipeline :require_authenticated_human do
    plug JidoCodeWeb.ProductAuth, :fetch_current_scope
    plug JidoCodeWeb.ProductAuth, :require_authenticated_human
  end

  pipeline :require_same_origin do
    plug JidoCodeWeb.Plugs.RequireSameOrigin
  end

  for area <- JidoCode.Identity.RoutePolicy.areas() do
    pipeline String.to_atom("authorize_#{area}") do
      plug JidoCodeWeb.Plugs.RequireProductArea, area
    end
  end

  if Application.compile_env(:jido_code, :hypermedia_qualification_build, false) do
    pipeline :hypermedia_qualification do
      plug JidoCodeWeb.Plugs.HypermediaQualificationAccess
    end
  end

  scope "/", JidoCodeWeb do
    pipe_through :browser

    get "/sign-in", AuthController, :new
  end

  scope "/", JidoCodeWeb do
    pipe_through [:browser, :require_same_origin]

    post "/sign-in", AuthController, :create
    delete "/sign-out", AuthController, :delete
  end

  scope "/", JidoCodeWeb do
    pipe_through [:browser, :require_authenticated_human, :require_same_origin]

    delete "/sessions", AuthController, :delete_all
  end

  scope "/api/v1", JidoCodeWeb.Api.V1 do
    pipe_through [:api, :require_authenticated_api]

    get "/agent-offerings", AgentOfferingController, :index
    post "/coding-attempts", CodingAttemptController, :create
    get "/coding-attempts/:attempt_ref", CodingAttemptController, :show
    post "/coding-attempts/:attempt_ref/refresh", CodingAttemptController, :refresh
    post "/coding-attempts/:attempt_ref/controls/:control", CodingAttemptController, :control
  end

  if Application.compile_env(:jido_code, :hypermedia_qualification_build, false) do
    scope "/__qualification", JidoCodeWeb.Qualification do
      pipe_through [:browser, :hypermedia_qualification]

      get "/hypermedia", HypermediaController, :index
      get "/hypermedia/results", HypermediaController, :results
      post "/hypermedia/submissions", HypermediaController, :submit
      get "/hypermedia/fragments/results", HypermediaController, :fragment_results
      post "/hypermedia/events/:event", HypermediaController, :event
      post "/hypermedia/stream", HypermediaController, :stream_fixture
      get "/hypermedia/maintenance", HypermediaController, :maintenance
      get "/hypermedia/error", HypermediaController, :error
    end
  end

  scope "/", JidoCodeWeb do
    pipe_through [:browser, :require_authenticated_human]

    live_session :authenticated,
      on_mount: [{JidoCodeWeb.ProductAuth, :require_authenticated}] do
      live "/", HomeLive
      live "/coding-agents", CodingAgentLive
      live "/managed-coding/:attempt_ref", ManagedCodingAttemptLive, :show
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", JidoCodeWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:jido_code, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:browser, :require_authenticated_human]

      live_dashboard "/dashboard", metrics: JidoCodeWeb.Telemetry
    end
  end
end
