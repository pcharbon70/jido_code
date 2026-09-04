defmodule JidoCodeWeb.HypermediaUIPhaseB2Fixture do
  @moduledoc false

  use JidoCodeWeb, :html

  attr :hostile_content, :string, required: true

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :form,
        to_form(%{"native_name" => "Native", "qualified_name" => "Qualified"}, as: :probe)
      )

    ~H"""
    <section id="hui-b2-facade-fixture" aria-labelledby="hui-b2-facade-title">
      <h1 id="hui-b2-facade-title">Qualified component facade</h1>

      <.form for={@form} id="hui-b2-form" action="/qualification-only" method="post">
        <.input field={@form[:native_name]} label="Native fallback input" />
        <UI.field_input
          field={@form[:qualified_name]}
          data-on:input="$draft = evt.target.value"
        >
          <:label>Qualified input</:label>
          <:help>Rendered with the same Phoenix form.</:help>
        </UI.field_input>
        <UI.button id="hui-b2-submit" type="submit" data-on:click="$pending = true">
          Save qualification fixture
        </UI.button>
      </.form>

      <UI.link id="hui-b2-link" href="/">Native navigation fallback</UI.link>
      <UI.badge id="hui-b2-badge" variant="outline">passive</UI.badge>

      <UI.table id="hui-b2-table" caption="Qualification evidence">
        <:head>
          <tr>
            <th scope="col">Evidence</th>
          </tr>
        </:head>
        <tr>
          <td>{@hostile_content}</td>
        </tr>
      </UI.table>

      <UI.disclosure id="hui-b2-disclosure">
        <:item key="details" summary="Evidence details">Native details content</:item>
      </UI.disclosure>

      <UI.dialog id="hui-b2-dialog">
        <:trigger>Open evidence</:trigger>
        <:title>Qualification evidence</:title>
        <:description>Native dialog behavior remains available without JavaScript.</:description>
        <p>Dialog body</p>
        <:close>Close</:close>
        <:fallback><a href="#hui-b2-table">Read the table instead</a></:fallback>
      </UI.dialog>

      <UI.status id="hui-b2-status" kind={:success}>Fixture rendered</UI.status>
    </section>
    """
  end
end
