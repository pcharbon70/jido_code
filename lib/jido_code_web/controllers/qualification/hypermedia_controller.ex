defmodule JidoCodeWeb.Qualification.HypermediaController do
  @moduledoc """
  Explicit controller boundary for the HUI-B3 non-product consumer.
  """

  use JidoCodeWeb, :controller

  alias JidoCodeWeb.Qualification.HypermediaFixture
  alias JidoCodeWeb.Qualification.HypermediaHTML
  alias JidoCodeWeb.Qualification.HypermediaRequestSecurity
  alias JidoCodeWeb.Qualification.HypermediaSignals
  alias JidoCodeWeb.Qualification.HypermediaStreamCoordinator
  alias JidoCodeWeb.Qualification.HypermediaStreamFixture

  def index(conn, params), do: render_consumer(conn, params)

  def results(conn, params), do: render_consumer(conn, params)

  def fragment_results(conn, _params) do
    with {:ok, conn} <- HypermediaRequestSecurity.admit(conn, :get),
         {:ok, signals} <- HypermediaSignals.read_get(conn, ~w(q state page)) do
      view = HypermediaFixture.view(signals)

      conn
      |> Dstar.start()
      |> Dstar.patch_elements(results_html(view),
        selector: "#hui-b3-results-region",
        mode: :outer,
        event_id: "hui-b3-results-#{view.page}"
      )
      |> Dstar.patch_signals(%{
        _fixture_freshness: "fresh",
        _fixture_page: view.page,
        _pending: false
      })
    else
      {:error, reason} -> HypermediaRequestSecurity.reject(conn, rejection_status(reason), reason)
    end
  end

  def event(conn, %{"event" => "validate-note"}) do
    with {:ok, conn} <- HypermediaRequestSecurity.admit(conn, :post),
         {:ok, signals} <- HypermediaSignals.read_body(conn, ~w(note)) do
      case HypermediaFixture.validate_note(signals) do
        {:ok, note} ->
          enhanced_outcome(conn, :success, "Fixture note accepted: #{note}")

        {:error, _note, _errors} ->
          enhanced_outcome(conn, :failure, "Fixture note must contain 3 through 80 characters.")
      end
    else
      {:error, reason} -> HypermediaRequestSecurity.reject(conn, rejection_status(reason), reason)
    end
  end

  def event(conn, %{"event" => _unsupported}) do
    HypermediaRequestSecurity.reject(conn, :not_found, :unsupported_event)
  end

  def stream_fixture(conn, _params) do
    with {:ok, conn} <- HypermediaRequestSecurity.admit(conn, :post),
         {:ok, signals} <- HypermediaSignals.read_body(conn, ~w(tabId scenario)),
         scenario = Map.get(signals, "scenario", "normal"),
         {:ok, token, correlation} <-
           HypermediaStreamCoordinator.acquire(Map.get(signals, "tabId")) do
      try do
        conn = Dstar.start(conn)

        case HypermediaStreamFixture.run(
               conn,
               token,
               scenario,
               correlation,
               stream_status_html("connected", "snapshot", "Bounded fixture stream admitted.")
             ) do
          {:ok, conn} ->
            :ok = HypermediaStreamCoordinator.release(token, :completed)
            conn

          {:error, _reason, conn} ->
            conn
        end
      after
        HypermediaStreamCoordinator.release(token, :cancelled)
      end
    else
      {:error, reason} -> HypermediaRequestSecurity.reject(conn, rejection_status(reason), reason)
    end
  end

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

    stream_form = Phoenix.Component.to_form(%{"scenario" => "normal"}, as: :stream)

    tab_id = Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

    conn
    |> put_status(Keyword.get(options, :status, :ok))
    |> render(:index,
      page_title: "HUI-B3 qualification consumer",
      view: view,
      filter_form: filter_form,
      note_form: note_form,
      stream_form: stream_form,
      outcome: Keyword.get(options, :outcome),
      submitted_note: Keyword.get(options, :submitted_note),
      previous_url: page_url(view, max(view.page - 1, 1)),
      next_url: page_url(view, min(view.page + 1, view.page_count)),
      root_signal_attrs: %{
        "data-signals:_pending" => "false",
        "data-signals:_stream-pending" => "false",
        "data-signals:_connection-state" => "'idle'",
        "data-signals:_fixture-freshness" => "'native'",
        "data-signals:_terminal" => "false",
        "data-signals:scenario" => "'normal'",
        "data-signals:tab-id" => "'#{tab_id}'"
      },
      filter_button_attrs: %{
        "data-attr:disabled" => "$_pending",
        "data-indicator:_pending" => "",
        "data-on:click__prevent" =>
          "@get('/__qualification/hypermedia/fragments/results', {filterSignals: {include: /^(q|state|page)$/}, requestCancellation: 'auto'})"
      },
      note_button_attrs: %{
        "data-attr:disabled" => "$_pending",
        "data-indicator:_pending" => "",
        "data-on:click__prevent" =>
          "@post('/__qualification/hypermedia/events/validate-note', {headers: {'x-csrf-token': document.querySelector('meta[name=csrf-token]').content}, filterSignals: {include: /^note$/}, requestCancellation: 'auto'})"
      },
      stream_button_attrs: %{
        "data-attr:disabled" => "$_streamPending",
        "data-indicator:_stream-pending" => "",
        "data-on:click__prevent" =>
          "@post('/__qualification/hypermedia/stream', {headers: {'x-csrf-token': document.querySelector('meta[name=csrf-token]').content}, filterSignals: {include: /^(tabId|scenario)$/}, requestCancellation: 'auto', retry: 'auto', retryInterval: #{HypermediaStreamFixture.retry_ms()}})"
      },
      query_signal_attrs: %{"data-bind:q" => ""},
      state_signal_attrs: %{"data-bind:state" => ""},
      note_signal_attrs: %{"data-bind:note" => ""},
      scenario_signal_attrs: %{"data-bind:scenario" => ""}
    )
  end

  defp results_html(view) do
    HypermediaHTML.results(%{
      view: view,
      previous_url: page_url(view, max(view.page - 1, 1)),
      next_url: page_url(view, min(view.page + 1, view.page_count))
    })
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp enhanced_outcome(conn, kind, message) do
    html =
      HypermediaHTML.enhanced_outcome(%{kind: kind, message: message})
      |> Phoenix.HTML.Safe.to_iodata()
      |> IO.iodata_to_binary()

    conn
    |> Dstar.start()
    |> Dstar.patch_elements(html,
      selector: "#hui-b3-enhanced-outcome",
      mode: :outer,
      event_id: "hui-b3-note-outcome"
    )
    |> Dstar.patch_signals(%{_pending: false})
  end

  defp stream_status_html(connection, freshness, message) do
    HypermediaHTML.stream_status(%{
      connection: connection,
      freshness: freshness,
      message: message
    })
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp rejection_status(reason) when reason in [:connection_ceiling, :duplicate_tab],
    do: :too_many_requests

  defp rejection_status(reason)
       when reason in [:invalid_origin, :cross_site_request, :enhanced_request_required],
       do: :forbidden

  defp rejection_status(_reason), do: :unprocessable_entity

  defp page_url(view, page) do
    ~p"/__qualification/hypermedia/results?#{%{q: view.query, state: view.state, page: page}}"
  end
end
