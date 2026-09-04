defmodule JidoCodeWeb.Qualification.HypermediaControllerTest do
  use JidoCodeWeb.ConnCase, async: false

  setup do
    prior = Application.get_env(:jido_code, :hypermedia_qualification)

    Application.put_env(:jido_code, :hypermedia_qualification,
      enabled: true,
      allowed_hosts: ["www.example.com"]
    )

    on_exit(fn -> Application.put_env(:jido_code, :hypermedia_qualification, prior) end)
  end

  test "renders the isolated native consumer with stable contracts and escaped fixtures", %{
    conn: conn
  } do
    conn = get(conn, ~p"/__qualification/hypermedia?q=hostile&disclosure=open&dialog=open")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert present?(document, "#hui-b3-consumer[data-qualification-only]")
    assert present?(document, "#hui-b3-filter-form[method='get']")
    assert present?(document, "#hui-b3-note-form[method='post'] input[name='_csrf_token']")
    assert present?(document, "#hui-b3-results-region #fixture-hostile")
    assert present?(document, "#hui-b3-disclosure-item-protocol[open]")
    assert present?(document, "#hui-b3-dialog-invoker[command='show-modal']")

    assert LazyHTML.text(LazyHTML.query(document, "#hui-b3-dialog-fallback")) =~
             "deep-link requested"

    assert LazyHTML.text(LazyHTML.query(document, "#fixture-hostile td:first-child")) ==
             "<unsafe>& hostile label"

    refute present?(document, "script:not([src])")
  end

  test "supports deep-linked empty, loading, pagination, maintenance, and safe error states", %{
    conn: conn
  } do
    empty = conn |> get(~p"/__qualification/hypermedia?state=empty") |> document(200)
    loading = build_conn() |> get(~p"/__qualification/hypermedia?state=loading") |> document(200)
    second = build_conn() |> get(~p"/__qualification/hypermedia/results?page=2") |> document(200)

    maintenance =
      build_conn() |> get(~p"/__qualification/hypermedia/maintenance") |> document(503)

    error = build_conn() |> get(~p"/__qualification/hypermedia/error") |> document(500)

    assert present?(empty, "#hui-b3-empty-state")
    assert present?(loading, "#hui-b3-loading-state[role='status']")
    assert present?(second, "#fixture-charlie")
    assert LazyHTML.text(LazyHTML.query(second, "#hui-b3-page-position")) == "Page 2 of 2"
    assert present?(maintenance, "#hui-b3-maintenance[role='status']")
    assert present?(error, "#hui-b3-safe-error[role='status']")
  end

  test "validates the native POST without durable mutation and escapes echoed content", %{
    conn: conn
  } do
    invalid =
      post(conn, ~p"/__qualification/hypermedia/submissions", %{
        "qualification" => %{"note" => "x"}
      })

    invalid_document = document(invalid, 422)
    assert present?(invalid_document, "#hui-b3-submit-error")
    assert present?(invalid_document, "#qualification_note.input-error")

    assert LazyHTML.text(LazyHTML.query(invalid_document, "#hui-b3-note-form p")) =~
             "must contain at least 3 characters"

    accepted =
      build_conn()
      |> post(~p"/__qualification/hypermedia/submissions", %{
        "qualification" => %{"note" => "<script>alert(1)</script>"}
      })
      |> document(200)

    assert LazyHTML.text(LazyHTML.query(accepted, "#hui-b3-submitted-note")) ==
             "<script>alert(1)</script>"

    refute present?(accepted, "#hui-b3-submitted-note script")

    reloaded = build_conn() |> get(~p"/__qualification/hypermedia") |> document(200)
    refute present?(reloaded, "#hui-b3-submit-success")
  end

  defp document(conn, status), do: conn |> html_response(status) |> LazyHTML.from_document()

  defp present?(document, selector) do
    document |> LazyHTML.query(selector) |> LazyHTML.to_html() != ""
  end
end
