defmodule JidoCodeWeb.DeliveryRollbackTest do
  use ExUnit.Case, async: false
  alias JidoCode.Product.{DeliveryControl, StreamCoordinator}
  alias JidoCode.TestSupport.HypermediaStreamHTTPFixture, as: HTTP

  setup do
    old = Application.get_env(:jido_code, :hypermedia_delivery_enabled)
    Application.put_env(:jido_code, :hypermedia_delivery_enabled, true)
    base = HTTP.start!()

    on_exit(fn ->
      if old == nil,
        do: Application.delete_env(:jido_code, :hypermedia_delivery_enabled),
        else: Application.put_env(:jido_code, :hypermedia_delivery_enabled, old)
    end)

    %{client: HTTP.sign_in(base)}
  end

  test "rollback closes streams, preserves sessions and native routes, and refuses stale enhancement",
       %{client: client} do
    stream = HTTP.connect(client)
    assert :ok = DeliveryControl.disable()
    HTTP.eventually(fn -> StreamCoordinator.stats().connections == 0 end)
    assert {:ok, _} = JidoCode.Identity.Sessions.validate(client.session, touch: false)
    assert {:ok, %{status: 503}} = HTTP.post(client, "/fleet", HTTP.payload("fleet"))

    assert {:ok, %{status: 503}} =
             Req.post(client.base <> "/ui/reads/fleet",
               json: %{read_fleet: %{}},
               retry: false,
               headers: %{
                 "cookie" => client.cookie,
                 "origin" => client.base,
                 "x-csrf-token" => client.csrf,
                 "accept" => "text/html",
                 "datastar-request" => "true",
                 "sec-fetch-site" => "same-origin"
               }
             )

    page =
      Req.get!(client.base <> "/factory/fleet",
        headers: %{"cookie" => client.cookie},
        retry: false
      )

    assert page.status == 200
    document = LazyHTML.from_document(page.body)
    assert LazyHTML.query(document, "#product-shell") |> Enum.count() == 1
    assert LazyHTML.query(document, "#product-owned-content") |> Enum.count() == 1

    assert LazyHTML.query(document, "#product-stream-controls, [data-read-endpoint]")
           |> Enum.count() == 0

    HTTP.finish(stream)
  end
end
