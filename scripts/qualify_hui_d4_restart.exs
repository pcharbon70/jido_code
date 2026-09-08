# Failed local deployment configuration must not open a different writable store.
fn base, credential ->
  alias JidoCode.Knowledge.StoreServer
  original = Application.fetch_env!(:jido_code, :knowledge_store)
  false = File.exists?("invalid-relative-root")
  revision = StoreServer.summary().dataset_revision
  {:ok, authentication} = JidoCode.Identity.authenticate("local-proof@example.test", credential)
  {:ok, session} = JidoCode.Identity.Sessions.issue(authentication)
  :ok = JidoCode.LocalDeployment.drain()
  :ok = Application.stop(:jido_code)

  try do
    Application.put_env(
      :jido_code,
      :knowledge_store,
      Keyword.put(original, :root, "invalid-relative-root")
    )

    # The supervisor may remain up to serve safe maintenance responses, but it
    # must never become ready or create a writable relative-path dataset.
    Application.ensure_all_started(:jido_code)

    true =
      Enum.any?(1..150, fn _ ->
        false = JidoCode.LocalDeployment.readiness().ready?

        case JidoCode.Knowledge.health() do
          %{failure: %JidoCode.Knowledge.Error{}} ->
            true

          _ ->
            Process.sleep(100)
            false
        end
      end)

    false = File.exists?("invalid-relative-root")
  after
    Application.stop(:jido_code)
    Application.put_env(:jido_code, :knowledge_store, original)
    {:ok, _} = Application.ensure_all_started(:jido_code)
  end

  true =
    Enum.any?(1..150, fn _ ->
      if JidoCode.LocalDeployment.readiness().ready?,
        do: true,
        else:
          (
            Process.sleep(100)
            false
          )
    end)

  ^revision = StoreServer.summary().dataset_revision
  {:ok, _} = JidoCode.Identity.Sessions.validate(session.session_ref, touch: false)
  %{status: 200} = Req.get!(base <> "/sign-in", retry: false)

  IO.puts(
    Jason.encode!(%{
      failed_restart: "invalid store configuration",
      recovery: "pass",
      graph_revision_unchanged: true,
      existing_session_preserved: true
    })
  )

  :ok
end
