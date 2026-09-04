defmodule JidoCodeWeb.Qualification.HypermediaController do
  @moduledoc """
  Explicit controller boundary for the HUI-B3 non-product consumer.
  """

  use JidoCodeWeb, :controller

  alias JidoCodeWeb.Qualification.HypermediaFixture

  def index(conn, params), do: render_consumer(conn, params)

  def results(conn, params), do: render_consumer(conn, params)

  def submit(conn, %{"qualification" => params}) when is_map(params) do
    case HypermediaFixture.validate_note(params) do
      {:ok, note} ->
        render_consumer(conn, %{}, submitted_note: note, outcome: :success)

      {:error, note, errors} ->
        render_consumer(conn, %{},
          status: :unprocessable_entity,
          note: note,
          note_errors: errors,
          outcome: :failure
        )
    end
  end

  def submit(conn, _params) do
    render_consumer(conn, %{},
      status: :unprocessable_entity,
      note_errors: [note: {"is required", []}],
      outcome: :failure
    )
  end

  def maintenance(conn, _params) do
    render_consumer(conn, %{"state" => "error"},
      status: :service_unavailable,
      outcome: :maintenance
    )
  end

  def error(conn, _params) do
    render_consumer(conn, %{"state" => "error"},
      status: :internal_server_error,
      outcome: :error
    )
  end

  defp render_consumer(conn, params, options \\ []) do
    view = HypermediaFixture.view(params)
    note = Keyword.get(options, :note, "")

    filter_form =
      Phoenix.Component.to_form(%{"q" => view.query, "state" => view.state}, as: :filters)

    note_form =
      Phoenix.Component.to_form(%{"note" => note},
        as: :qualification,
        errors: Keyword.get(options, :note_errors, []),
        action: if(Keyword.has_key?(options, :note_errors), do: :validate, else: nil)
      )

    conn
    |> put_status(Keyword.get(options, :status, :ok))
    |> render(:index,
      page_title: "HUI-B3 qualification consumer",
      view: view,
      filter_form: filter_form,
      note_form: note_form,
      outcome: Keyword.get(options, :outcome),
      submitted_note: Keyword.get(options, :submitted_note),
      previous_url: page_url(view, max(view.page - 1, 1)),
      next_url: page_url(view, min(view.page + 1, view.page_count))
    )
  end

  defp page_url(view, page) do
    ~p"/__qualification/hypermedia/results?#{%{q: view.query, state: view.state, page: page}}"
  end
end
