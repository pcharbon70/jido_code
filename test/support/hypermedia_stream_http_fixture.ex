defmodule JidoCode.TestSupport.HypermediaStreamHTTPFixture do
  @moduledoc false
  import ExUnit.Assertions
  alias JidoCode.Product.{ReadRequestLimiter, StreamCoordinator}
  alias JidoCode.Identity.Store

  def start! do
    listener =
      ExUnit.Callbacks.start_supervised!(
        {Bandit, plug: JidoCodeWeb.Endpoint, port: 0, ip: {127, 0, 0, 1}}
      )

    {:ok, {_, port}} = ThousandIsland.listener_info(listener)
    reset!()

    ExUnit.Callbacks.on_exit(fn ->
      StreamCoordinator.drain()
      eventually(fn -> StreamCoordinator.stats().connections == 0 end)
      reset!()
    end)

    "http://127.0.0.1:#{port}"
  end

  def reset! do
    :ok = Supervisor.terminate_child(JidoCode.Supervisor, StreamCoordinator)
    {:ok, _} = Supervisor.restart_child(JidoCode.Supervisor, StreamCoordinator)
    :sys.replace_state(ReadRequestLimiter, fn _ -> %{windows: %{}, leases: %{}} end)
  end

  def sign_in(base, login \\ "operator@example.test") do
    before = Map.keys(:sys.get_state(Store).data.sessions)
    guest = Req.get!(base <> "/sign-in", retry: false)

    response =
      Req.post!(base <> "/sign-in",
        retry: false,
        redirect: false,
        headers: %{"cookie" => cookie(guest), "origin" => base},
        form: %{
          "_csrf_token" => csrf(guest.body),
          "session[login]" => login,
          "session[credential]" => "test-named-human-credential",
          "session[return_to]" => "/factory/fleet"
        }
      )

    assert response.status == 302
    cookie = cookie(response)
    page = Req.get!(base <> "/factory/fleet", retry: false, headers: %{"cookie" => cookie})
    assert page.status == 200
    [session] = Map.keys(:sys.get_state(Store).data.sessions) -- before

    %{
      base: base,
      cookie: if(page.headers["set-cookie"], do: cookie(page), else: cookie),
      csrf: csrf(page.body),
      session: session
    }
  end

  def post(client, route, raw, options \\ []) do
    Req.post(
      client.base <> "/ui/streams" <> route,
      Keyword.merge(
        [
          retry: false,
          redirect: false,
          receive_timeout: 15_000,
          decode_body: false,
          body: raw,
          headers: %{
            "accept" => "text/event-stream",
            "content-type" => "application/json",
            "cookie" => client.cookie,
            "x-csrf-token" => client.csrf,
            "origin" => client.base,
            "sec-fetch-site" => "same-origin",
            "datastar-request" => "true"
          }
        ],
        options
      )
    )
  end

  def payload(surface \\ "fleet", correlation \\ %{}, query \\ %{}) do
    Jason.encode!(%{
      "stream" => Map.merge(%{tab: random(), request: random()}, correlation),
      "read_#{surface}" => query
    })
  end

  def connect(client, route \\ "/fleet", raw \\ payload()) do
    parent = self()
    tag = make_ref()

    task =
      Task.async(fn ->
        post(client, route, raw,
          into: fn {:data, bytes}, {request, response} ->
            send(parent, {tag, bytes})
            {:cont, {request, %{response | body: response.body <> bytes}}}
          end
        )
      end)

    stream = %{task: task, tag: tag}
    initial = until(stream, &(documents(&1) != []))
    Map.put(stream, :initial, initial)
  end

  def until(stream, predicate, timeout \\ 10_000),
    do: receive_until(stream.tag, predicate, "", System.monotonic_time(:millisecond) + timeout)

  defp receive_until(tag, predicate, buffer, deadline) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^tag, bytes} ->
        next = buffer <> bytes
        assert byte_size(next) <= 1_048_576
        if predicate.(next), do: next, else: receive_until(tag, predicate, next, deadline)
    after
      remaining ->
        states = Enum.map(documents(buffer), &LazyHTML.text/1)
        flunk("bounded HTTP stream did not reach the expected state: #{inspect(states)}")
    end
  end

  def documents(body) do
    body
    |> String.split("\n\n")
    |> Enum.drop(-1)
    |> Enum.filter(&String.contains?(&1, "event: datastar-patch-elements"))
    |> Enum.map(fn event ->
      event
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "data: elements "))
      |> Enum.map_join("\n", &String.replace_prefix(&1, "data: elements ", ""))
      |> LazyHTML.from_fragment()
    end)
  end

  def terminal?(body),
    do:
      Enum.any?(
        documents(body),
        &Enum.any?(LazyHTML.query(&1, "#product-shell[data-stream-terminal]"))
      )

  def finish(stream) do
    assert {:ok, %Req.Response{status: 200} = response} = Task.await(stream.task, 10_000)
    response
  end

  def eventually(fun, attempts \\ 100)
  def eventually(fun, 0), do: assert(fun.())

  def eventually(fun, attempts) do
    if fun.(),
      do: :ok,
      else:
        (
          Process.sleep(20)
          eventually(fun, attempts - 1)
        )
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

  def random, do: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
end
