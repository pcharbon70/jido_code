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

  pipeline :require_authenticated_operator do
    plug JidoCodeWeb.ProductAuth, :fetch_current_scope
    plug JidoCodeWeb.ProductAuth, :require_authenticated_operator
  end

  pipeline :hypermedia_qualification do
    plug JidoCodeWeb.Plugs.HypermediaQualificationAccess
  end

  scope "/", JidoCodeWeb do
    pipe_through :browser

    get "/sign-in", AuthController, :new
    post "/sign-in", AuthController, :create
    delete "/sign-out", AuthController, :delete
  end

  scope "/api/v1", JidoCodeWeb.Api.V1 do
    pipe_through [:api, :require_authenticated_api]

    get "/agent-offerings", AgentOfferingController, :index
    post "/coding-attempts", CodingAttemptController, :create
    get "/coding-attempts/:attempt_ref", CodingAttemptController, :show
    post "/coding-attempts/:attempt_ref/refresh", CodingAttemptController, :refresh
    post "/coding-attempts/:attempt_ref/controls/:control", CodingAttemptController, :control
  end

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

  scope "/", JidoCodeWeb do
    pipe_through [:browser, :require_authenticated_operator]

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
      pipe_through [:browser, :require_authenticated_operator]

      live_dashboard "/dashboard", metrics: JidoCodeWeb.Telemetry
    end
  end
end
