defmodule JidoCodeWeb.StreamReauthorizationTest do
  use JidoCodeWeb.ConnCase, async: false
  alias JidoCode.Identity.{Sessions, Store, Revocations}
  alias JidoCodeWeb.{ProductRequest, StreamDelivery}

  setup %{conn: conn} do
    page = conn |> init_test_session(%{}) |> sign_in_named_human() |> get("/factory/fleet")
    {spec, params, _} = page.private.read_authorization
    spec = Map.put(spec, :action, :stream)

    page =
      assign(
        page,
        :request_id,
        "stream-test-" <> Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
      )

    assert {:ok, current} = ProductRequest.evaluate(page, spec, params)
    page = put_private(page, :read_authorization, {spec, params, current.authorization})
    %{page: page, session_ref: page.assigns.authenticated_human.session_ref}
  end

  test "lost hints cannot hide any changed generation from the periodic or pre-patch fence",
       context do
    assert :ok = StreamDelivery.reauthorize(context.page)
    original = Map.take(:sys.get_state(Store).data, [:generations, :accounts, :sessions])
    subject = context.page.assigns.authenticated_human.account.subject_ref

    try do
      for dimension <- Revocations.dimensions() do
        # Deliberately drop PubSub: only authoritative fixture state changes.
        :sys.replace_state(Store, fn state ->
          state = %{state | data: Map.merge(state.data, original)}

          case dimension do
            :account ->
              update_in(state.data.accounts[subject].account_generation, &(&1 + 1))

            :session ->
              update_in(state.data.sessions[context.session_ref].session_generation, &(&1 + 1))

            global ->
              update_in(state.data.generations[global], &(&1 + 1))
          end
        end)

        expected = if dimension == :account, do: :revoked, else: :changed

        assert {:error, ^expected} = StreamDelivery.reauthorize(context.page),
               "missed #{dimension} fence"
      end
    after
      :sys.replace_state(Store, fn state -> %{state | data: Map.merge(state.data, original)} end)
    end

    events = Store.evidence(:audit)
    matching = Enum.filter(events, &(&1.receipt_ref == context.page.assigns.request_id))
    assert length(matching) >= 9
    assert Enum.all?(matching, &(&1.action_ref == "identity.authorization.factory_shell"))
  end

  test "background traffic never touches idle expiry and hard session expiry fails closed",
       context do
    assert {:ok, %{session: before}} = Sessions.validate(context.session_ref, touch: false)
    for _ <- 1..3, do: assert(:ok == StreamDelivery.reauthorize(context.page))
    assert {:ok, %{session: after_checks}} = Sessions.validate(context.session_ref, touch: false)
    assert before.last_seen_at == after_checks.last_seen_at
    assert before.idle_expires_at == after_checks.idle_expires_at

    :sys.replace_state(Store, fn state ->
      put_in(
        state.data.sessions[context.session_ref].hard_expires_at,
        DateTime.add(DateTime.utc_now(), -1, :second)
      )
    end)

    assert {:error, :revoked} = StreamDelivery.reauthorize(context.page)
  end

  test "current session revocation defeats an open response and repeated reauthorization",
       context do
    {:ok, sessions} = Sessions.managed(context.session_ref)
    current = Enum.find(sessions, & &1.current)
    assert {:ok, :current} = Sessions.revoke_managed(context.session_ref, current.management_ref)
    for _ <- 1..3, do: assert({:error, :revoked} == StreamDelivery.reauthorize(context.page))
  end
end
