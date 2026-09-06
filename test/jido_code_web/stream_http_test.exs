defmodule JidoCodeWeb.StreamHTTPTest do
  use ExUnit.Case, async: false
  alias JidoCode.Product.{ReadRequestLimiter, StreamCoordinator}
  alias JidoCode.Identity.{Store, Revocations}
  alias JidoCode.TestSupport.HypermediaUIPhaseC4Fixture, as: Fixture

  setup do
    # Real Bandit sockets and Endpoint, with the production application-owned
    # coordinator/watchdog supervisor. Only bounded query data is a fixture.
    listener =
      start_supervised!({Bandit, plug: JidoCodeWeb.Endpoint, port: 0, ip: {127, 0, 0, 1}})

    {:ok, {_, port}} = ThousandIsland.listener_info(listener)
    base = "http://127.0.0.1:#{port}"
    keys = [:product_read_projection_provider, :read_projection_fixture]
    prior = Map.new(keys, &{&1, Application.get_env(:jido_code, &1)})

    Application.put_env(
      :jido_code,
      :product_read_projection_provider,
      JidoCode.TestSupport.FakeReadProjectionProvider
    )

    Application.put_env(:jido_code, :read_projection_fixture, &Fixture.projection(&1.page.key))
    reset_coordinator()
    client = sign_in(base)

    on_exit(fn ->
      StreamCoordinator.drain()
      eventually(fn -> StreamCoordinator.stats().connections == 0 end)
      reset_coordinator()

      Enum.each(prior, fn {key, value} ->
        if value == nil,
          do: Application.delete_env(:jido_code, key),
          else: Application.put_env(:jido_code, key, value)
      end)
    end)

    %{client: client, base: base}
  end

  test "HTTP admission rejects security and closed-schema failures without SSE or leases", %{
    client: client
  } do
    for {changes, expected} <- [
          {%{"accept" => "text/html"}, 406},
          {%{"origin" => "https://untrusted.test"}, 403},
          {%{"sec-fetch-site" => "cross-site"}, 403},
          {%{"datastar-request" => "false"}, 403},
          {%{"content-type" => "text/plain"}, 415},
          {%{"x-csrf-token" => "invalid"}, 403}
        ] do
      response = post(client, payload(), headers: changes)
      assert response.status == expected
      refute sse?(response)
    end

    assert post(client, "{}").status == 422
    assert post(client, String.duplicate("x", 2049)).status == 413
    assert post(client, payload(), route: "/projects/unknown/overview").status == 422

    response =
      post(client, payload("attempt"),
        route: "/projects/project_browser_beta/attempts/attempt_browser_alpha"
      )

    assert response.status == 404
    assert post(client, payload(), headers: %{"last-event-id" => "copied"}).status == 422
    # A real CSRF-bearing anonymous session, not a missing-cookie CSRF shortcut.
    anonymous = anonymous(client.base)
    assert post(anonymous, payload()).status == 401
    eventually(fn -> StreamCoordinator.stats().connections == 0 end)
  end

  test "stream starts before EOF, emits private bounded events, expires and frees production owners",
       %{client: client} do
    limits(%{idle_ms: 700, heartbeat_ms: 200, reauthorize_ms: 100})
    active = connect(client)
    assert active.response.status == 200
    assert sse?(active.response)
    assert active.response.headers["cache-control"] == ["no-store, private"]
    assert active.response.headers["x-accel-buffering"] == ["no"]
    assert StreamCoordinator.stats().connections == 1
    response = finish(active)
    assert response.body =~ ": heartbeat"
    assert terminal?(response.body)
    assert length(protected_roots(response.body)) == 1
    assert byte_size(response.body) <= StreamCoordinator.limits().total_bytes
    assert Enum.all?(String.split(response.body, "\n\n", trim: true), &(byte_size(&1) <= 131_072))
    eventually(fn -> StreamCoordinator.stats().connections == 0 and guard_count() == 0 end)
  end

  test "duplicate and cross-route takeover keep exact leases and copied cursors cannot change scope",
       %{client: client} do
    tab = random()
    raw = payload("fleet", %{tab: tab, request: random()})
    first = connect(client, raw)
    assert post(client, raw).status == 409
    assert StreamCoordinator.stats().connections == 1
    cursor = Regex.run(~r/^id: (.+)$/m, first.initial) |> Enum.at(1)

    assert post(client, payload("projects", %{tab: tab, request: random(), cursor: cursor}),
             route: "/projects"
           ).status == 422

    second =
      connect(client, payload("projects", %{tab: tab, request: random()}), route: "/projects")

    assert terminal?(finish(first).body)
    eventually(fn -> StreamCoordinator.stats().connections == 1 end)

    assert second.initial
           |> document("#product-owned-content")
           |> LazyHTML.query("#product-owned-content")
           |> LazyHTML.attribute("data-read-surface") == ["projects"]

    StreamCoordinator.drain()
    assert terminal?(finish(second).body)
  end

  test "session and principal caps reject additional HTTP owners without eviction", %{
    client: client,
    base: base
  } do
    first = connect(client)
    second = connect(client)
    assert post(client, payload()).status == 429
    assert StreamCoordinator.stats().connections == 2
    other = sign_in(base)
    third = connect(other)
    fourth = connect(other)
    assert post(sign_in(base), payload()).status == 429
    assert StreamCoordinator.stats().connections == 4
    StreamCoordinator.drain()
    for active <- [first, second, third, fourth], do: assert(terminal?(finish(active).body))
    eventually(fn -> StreamCoordinator.stats().connections == 0 end)
  end

  test "lowered tenant and factory ceilings plus admission rate apply through real HTTP", %{
    client: client
  } do
    for dimension <- [:tenant, :factory] do
      limits(%{dimension => 1})
      first = connect(client)
      assert post(client, payload()).status == 429
      StreamCoordinator.drain()
      assert terminal?(finish(first).body)
      reset_coordinator()
    end

    limits(%{admissions: 2, idle_ms: 200})
    for _ <- 1..2, do: client |> connect() |> finish()
    assert post(client, payload()).status == 429
    eventually(fn -> StreamCoordinator.stats().connections == 0 end)
  end

  test "oversized patches and cumulative/event exhaustion never replay protected data", %{
    client: client
  } do
    for bounds <- [%{event_bytes: 1_024}, %{total_bytes: 1_024}, %{events: 1}] do
      limits(bounds)
      response = post(client, payload())
      refute response.status == 200
      refute sse?(response)
      eventually(fn -> StreamCoordinator.stats().connections == 0 end)
      reset_coordinator()
    end

    limits(%{events: 3, heartbeat_ms: 200, reauthorize_ms: 100})
    response = client |> connect() |> finish()
    assert length(protected_roots(response.body)) == 1
    assert terminal?(response.body)
    assert length(String.split(response.body, "\n\n", trim: true)) <= 3
  end

  test "disconnect, killed HTTP owner, coordinator restart and drain release sockets and capacity",
       %{client: client} do
    # A peer close can remain behind a transport's synchronous owner loop.
    # The independent idle deadline bounds cleanup even without a failed write.
    limits(%{idle_ms: 700, heartbeat_ms: 200})
    active = connect(client)
    Task.shutdown(active.task, :brutal_kill)
    eventually(fn -> StreamCoordinator.stats().connections == 0 end)

    active = connect(client)
    owner = :sys.get_state(StreamCoordinator).leases |> Map.values() |> hd() |> Map.fetch!(:owner)
    Process.exit(owner, :kill)
    assert {:error, _} = Task.await(active.task, 5_000)
    eventually(fn -> StreamCoordinator.stats().connections == 0 and guard_count() == 0 end)

    active = connect(client)
    coordinator = Process.whereis(StreamCoordinator)
    Process.exit(coordinator, :kill)
    eventually(fn -> Process.whereis(StreamCoordinator) not in [nil, coordinator] end)
    assert {:error, _} = Task.await(active.task, 5_000)
    eventually(fn -> StreamCoordinator.stats().connections == 0 and guard_count() == 0 end)

    active = connect(client)
    assert :ok = StreamCoordinator.drain()
    assert terminal?(finish(active).body)
    assert post(client, payload()).status == 503
  end

  test "a blocked real HTTP query is killed by the independent admission watchdog without data",
       %{client: client} do
    limits(%{admitted_ms: 200})
    parent = self()

    Application.put_env(:jido_code, :read_projection_fixture, fn _ ->
      send(parent, {:query_owner, self()})

      receive do
        :never -> Fixture.projection(:fleet)
      end
    end)

    task = Task.async(fn -> post(client, payload()) end)
    assert_receive {:query_owner, _}, 2_000
    # Depending on the bounded query worker's race with the owner watchdog,
    # the transport closes or returns a safe pre-header failure.
    result = Task.await(task, 5_000)

    assert match?({:error, _}, result) or
             (is_struct(result, Req.Response) and result.status != 200)

    eventually(fn -> StreamCoordinator.stats().connections == 0 and guard_count() == 0 end)
  end

  test "every changed generation during idle fails the fresh HTTP fence even with dropped hints",
       %{client: client} do
    original = fixture_authority()

    try do
      for dimension <- Revocations.dimensions() do
        restore_authority(original)
        reset_coordinator()
        limits(%{reauthorize_ms: 100})
        tab = random()
        active = connect(client, payload("fleet", %{tab: tab, request: random()}))
        change_generation(client, dimension)
        response = finish(active)
        assert terminal?(response.body), "missed #{dimension}"

        assert response.body
               |> document("#product-shell")
               |> LazyHTML.query("#product-shell")
               |> LazyHTML.attribute("data-stream-terminal") == ["revoked"]

        assert length(protected_roots(response.body)) == 1

        assert post(
                 client,
                 payload("fleet", %{tab: tab, request: random(), cursor: cursor(active)}),
                 headers: %{"last-event-id" => cursor(active)}
               ).status in [401, 422]
      end
    after
      restore_authority(original)
    end
  end

  test "all eight generations changed during query withhold the initial protected patch", %{
    client: client
  } do
    original = fixture_authority()

    try do
      for dimension <- Revocations.dimensions() do
        restore_authority(original)
        reset_coordinator()

        Application.put_env(:jido_code, :read_projection_fixture, fn _ ->
          change_generation(client, dimension)
          Fixture.projection(:fleet)
        end)

        response = post(client, payload())
        refute response.status == 200, "missed query fence #{dimension}"
        refute sse?(response)
        refute response.body =~ "data-read-namespace"
        eventually(fn -> StreamCoordinator.stats().connections == 0 end)
      end
    after
      restore_authority(original)
    end
  end

  test "shortened authoritative hard expiry closes an open socket despite heartbeats", %{
    client: client
  } do
    limits(%{reauthorize_ms: 100, heartbeat_ms: 200})
    active = connect(client)

    :sys.replace_state(Store, fn state ->
      put_in(
        state.data.sessions[client.session].hard_expires_at,
        DateTime.add(DateTime.utc_now(), -1, :second)
      )
    end)

    assert terminal?(finish(active).body)
    assert post(client, payload()).status == 401
  end

  test "a passive small-buffer reader cannot retain application owners past the deadline", %{
    client: client
  } do
    limits(%{idle_ms: 700, heartbeat_ms: 200, reauthorize_ms: 100})
    port = URI.parse(client.base).port

    {:ok, socket} =
      :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false, recbuf: 1_024])

    raw = payload()

    headers = [
      "POST /ui/streams/fleet HTTP/1.1",
      "Host: 127.0.0.1:#{port}",
      "Accept: text/event-stream",
      "Content-Type: application/json",
      "Cookie: #{client.cookie}",
      "X-CSRF-Token: #{client.csrf}",
      "Origin: #{client.base}",
      "Sec-Fetch-Site: same-origin",
      "Datastar-Request: true",
      "Content-Length: #{byte_size(raw)}",
      "Connection: close",
      "",
      raw
    ]

    try do
      :ok = :gen_tcp.send(socket, Enum.join(headers, "\r\n"))
      eventually(fn -> StreamCoordinator.stats().connections == 1 end)
      # No socket reads until the bounded owner has terminated. D2 deliberately
      # sends no domain update payload after its one bounded initial snapshot.
      state = :sys.get_state(StreamCoordinator)
      assert map_size(state.leases) == 1
      assert StreamCoordinator.stats().queued_payload_bytes == 0
      assert StreamCoordinator.stats().pending_hints <= 1
      eventually(fn -> StreamCoordinator.stats().connections == 0 and guard_count() == 0 end)
      {:ok, bytes} = :gen_tcp.recv(socket, 0, 2_000)
      assert bytes =~ "HTTP/1.1 200"
      assert byte_size(bytes) < StreamCoordinator.limits().total_bytes
    after
      :gen_tcp.close(socket)
    end
  end

  @tag timeout: 30_000
  test "whole application node death closes real streams and never restores a lease" do
    # A disposable child VM has its own production application supervision.
    # Kill only the OS PID returned by this exact Port, never a broad process match.
    program = """
    Application.put_env(:jido_code, :product_read_projection_provider, JidoCode.TestSupport.FakeReadProjectionProvider)
    Application.put_env(:jido_code, :read_projection_fixture, &JidoCode.TestSupport.HypermediaUIPhaseC4Fixture.projection(&1.page.key))
    {:ok, listener} = Bandit.start_link(plug: JidoCodeWeb.Endpoint, port: 0, ip: {127, 0, 0, 1})
    {:ok, {_, port}} = ThousandIsland.listener_info(listener)
    IO.puts("HUI_D2_NODE_READY=" <> Integer.to_string(port))
    Process.sleep(:infinity)
    """

    executable = System.find_executable("mix")

    port =
      Port.open({:spawn_executable, executable}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: ["run", "--no-compile", "--no-deps-check", "--eval", program],
        env: [{~c"MIX_ENV", ~c"test"}, {~c"ERL_FLAGS", ~c"+S 2:2"}]
      ])

    {:os_pid, os_pid} = Port.info(port, :os_pid)

    try do
      http_port = node_ready(port, "")
      client = sign_in("http://127.0.0.1:#{http_port}", false)
      active = connect(client)
      assert active.response.status == 200
      assert {_, 0} = System.cmd("kill", ["-KILL", Integer.to_string(os_pid)])
      assert_receive {^port, {:exit_status, _}}, 5_000
      assert {:error, _} = Task.await(active.task, 5_000)
      eventually(fn -> StreamCoordinator.stats().connections == 0 end)
    after
      if Port.info(port) do
        System.cmd("kill", ["-KILL", Integer.to_string(os_pid)])
        Port.close(port)
      end
    end
  end

  defp node_ready(port, buffer) do
    receive do
      {^port, {:data, bytes}} ->
        buffer = buffer <> bytes
        assert byte_size(buffer) < 65_536

        case Regex.run(~r/HUI_D2_NODE_READY=(\d+)/, buffer) do
          [_, value] -> String.to_integer(value)
          _ -> node_ready(port, buffer)
        end

      {^port, {:exit_status, code}} ->
        flunk("child node exited before ready: #{code}")
    after
      15_000 -> flunk("child node did not become ready")
    end
  end

  defp anonymous(base) do
    response = Req.get!(base <> "/sign-in", retry: false)
    %{base: base, cookie: cookie(response), csrf: csrf(response.body)}
  end

  defp sign_in(base, track_session \\ true) do
    before = Map.keys(:sys.get_state(Store).data.sessions)
    guest = anonymous(base)

    response =
      Req.post!(base <> "/sign-in",
        retry: false,
        redirect: false,
        headers: %{"cookie" => guest.cookie, "origin" => base},
        form: %{
          "_csrf_token" => guest.csrf,
          "session[login]" => "operator@example.test",
          "session[credential]" => "test-named-human-credential",
          "session[return_to]" => "/factory/fleet"
        }
      )

    assert response.status == 302
    cookie = cookie(response)
    page = Req.get!(base <> "/factory/fleet", retry: false, headers: %{"cookie" => cookie})
    assert page.status == 200

    session =
      if track_session do
        [value] = Map.keys(:sys.get_state(Store).data.sessions) -- before
        value
      end

    cookie = if Map.has_key?(page.headers, "set-cookie"), do: cookie(page), else: cookie
    %{base: base, cookie: cookie, csrf: csrf(page.body), session: session}
  end

  defp cookie(response),
    do:
      response.headers["set-cookie"]
      |> Enum.map(&(String.split(&1, ";", parts: 2) |> hd()))
      |> Enum.join("; ")

  defp csrf(body),
    do:
      body
      |> LazyHTML.from_document()
      |> LazyHTML.query("meta[name='csrf-token']")
      |> LazyHTML.attribute("content")
      |> hd()

  defp payload(surface \\ "fleet", correlation \\ %{tab: random(), request: random()}),
    do: Jason.encode!(%{"stream" => correlation, "read_#{surface}" => %{}})

  defp random, do: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)

  defp sse?(response),
    do: response.headers["content-type"] == ["text/event-stream; charset=utf-8"]

  defp cursor(active), do: Regex.run(~r/^id: (.+)$/m, active.initial) |> Enum.at(1)
  defp terminal?(body), do: body =~ "data: selector #product-shell"
  defp protected_roots(body), do: Regex.scan(~r/data: selector #product-owned-content/, body)

  defp document(body, selector) do
    body
    |> String.split("\n\n", trim: true)
    |> Enum.find(&String.contains?(&1, "data: selector " <> selector <> "\n"))
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "data: elements "))
    |> Enum.map_join("\n", &String.replace_prefix(&1, "data: elements ", ""))
    |> LazyHTML.from_fragment()
  end

  defp post(client, body, options \\ []) do
    headers = %{
      "accept" => "text/event-stream",
      "content-type" => "application/json",
      "cookie" => client.cookie,
      "x-csrf-token" => client.csrf,
      "origin" => client.base,
      "sec-fetch-site" => "same-origin",
      "datastar-request" => "true"
    }

    request_options =
      Keyword.merge(
        [retry: false, redirect: false, receive_timeout: 5_000, decode_body: false],
        Keyword.take(options, [:into])
      )

    result =
      Req.post(
        client.base <> "/ui/streams" <> Keyword.get(options, :route, "/fleet"),
        Keyword.merge(request_options,
          body: body,
          headers: Map.merge(headers, Keyword.get(options, :headers, %{}))
        )
      )

    case result do
      {:ok, response} -> response
      {:error, _} = error -> error
    end
  end

  defp connect(client, raw \\ payload(), options \\ []) do
    parent = self()
    tag = make_ref()

    task =
      Task.async(fn ->
        into = fn {:data, data}, {request, response} ->
          send(parent, {tag, response, data})
          {:cont, {request, %{response | body: response.body <> data}}}
        end

        post(client, raw, Keyword.put(options, :into, into))
      end)

    {response, initial} = first_event(tag, "")
    assert response.status == 200
    %{task: task, response: response, initial: initial}
  end

  defp first_event(tag, buffer) do
    receive do
      {^tag, response, data} ->
        buffer = buffer <> data

        if String.contains?(buffer, "\n\n"),
          do: {response, buffer},
          else: first_event(tag, buffer)
    after
      3_000 -> flunk("real HTTP stream did not deliver its first event")
    end
  end

  defp finish(active) do
    response = Task.await(active.task, 5_000)
    assert %Req.Response{status: 200} = response
    response
  end

  defp limits(changes),
    do: :sys.replace_state(StreamCoordinator, &%{&1 | limits: Map.merge(&1.limits, changes)})

  defp guard_count,
    do: DynamicSupervisor.count_children(JidoCode.Product.StreamOwnerSupervisor).active

  defp reset_coordinator do
    :ok = Supervisor.terminate_child(JidoCode.Supervisor, StreamCoordinator)
    {:ok, _} = Supervisor.restart_child(JidoCode.Supervisor, StreamCoordinator)
    :sys.replace_state(ReadRequestLimiter, fn _ -> %{windows: %{}, leases: %{}} end)
  end

  defp fixture_authority,
    do: Map.take(:sys.get_state(Store).data, [:accounts, :sessions, :generations])

  defp restore_authority(original),
    do: :sys.replace_state(Store, &%{&1 | data: Map.merge(&1.data, original)})

  defp change_generation(client, dimension) do
    # Fault injection only: intentionally omit PubSub to prove the fresh fence.
    :sys.replace_state(Store, fn state ->
      case dimension do
        :account ->
          update_in(state.data.accounts["human_test_operator"].account_generation, &(&1 + 1))

        :session ->
          update_in(state.data.sessions[client.session].session_generation, &(&1 + 1))

        global ->
          update_in(state.data.generations[global], &(&1 + 1))
      end
    end)
  end

  defp eventually(fun, remaining \\ 350) do
    cond do
      fun.() ->
        :ok

      remaining == 0 ->
        flunk("production owners or capacity did not converge")

      true ->
        Process.sleep(20)
        eventually(fun, remaining - 1)
    end
  end
end
