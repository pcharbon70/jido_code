defmodule JidoCodeWeb.HypermediaUIPhaseC2PrimitivesFixture do
  @moduledoc false

  use JidoCodeWeb, :html

  attr :hostile_content, :string, required: true

  def render(assigns) do
    form =
      to_form(
        %{
          "native_name" => "Native",
          "qualified_name" => "Qualified",
          "project" => "project-alpha",
          "accepted" => "false",
          "mode" => "review"
        },
        as: :primitive
      )

    assign(assigns, :form, form)
    |> render_fixture()
  end

  defp render_fixture(assigns) do
    ~H"""
    <section id="hui-c2-primitives" aria-labelledby="hui-c2-primitives-title">
      <h1 id="hui-c2-primitives-title">HUI-C2 supported primitive catalog</h1>

      <UI.form
        for={@form}
        id="hui-c2-form"
        action="/qualification-only"
        method="post"
        autocomplete="off"
      >
        <UI.input
          field={@form[:native_name]}
          id="hui-c2-native-input"
          label="Project input"
          required
        />

        <UI.field_input
          field={@form[:qualified_name]}
          id="hui-c2-field-input"
          errors={["Qualified name is required"]}
          error_mode={:always}
          required
        >
          <:label>Qualified input</:label>
          <:help>Use the reviewed display name.</:help>
        </UI.field_input>

        <UI.select
          field={@form[:project]}
          id="hui-c2-select"
          options={[
            %{key: "project-alpha", value: "project-alpha", label: "Project alpha"},
            %{key: "project-beta", value: "project-beta", label: "Project beta"}
          ]}
          errors={["Choose an authorized project"]}
          error_mode={:always}
          required
        >
          <:label>Project</:label>
          <:help>Only server-authorized projects appear.</:help>
        </UI.select>

        <UI.checkbox
          field={@form[:accepted]}
          id="hui-c2-checkbox"
          errors={["Confirm the reviewed scope"]}
          error_mode={:always}
          required
        >
          <:label>Confirm reviewed scope</:label>
          <:help>This browser choice does not grant authority.</:help>
        </UI.checkbox>

        <UI.radio_group
          field={@form[:mode]}
          id="hui-c2-radio-group"
          options={[
            %{key: "observe", value: "observe", label: "Observe"},
            %{key: "review", value: "review", label: "Review"}
          ]}
          errors={["Choose one presentation mode"]}
          error_mode={:always}
          required
        >
          <:legend>Presentation mode</:legend>
          <:help>Modes affect presentation only.</:help>
        </UI.radio_group>

        <UI.button id="hui-c2-submit" type="submit" variant={:default} size={:large}>
          Render catalog
        </UI.button>
      </UI.form>

      <nav id="hui-c2-native-navigation" aria-label="Primitive examples">
        <UI.link
          id="hui-c2-link"
          href="/qualification-only?view=primitives"
          title={@hostile_content}
        >
          Ordinary navigation
        </UI.link>
      </nav>

      <UI.badge id="hui-c2-badge" variant={:outline}>Ready label</UI.badge>

      <UI.table id="hui-c2-table" caption="Qualified primitive evidence">
        <:head>
          <tr>
            <th scope="col">Primitive</th>
            <th scope="col">Evidence</th>
          </tr>
        </:head>
        <tr id="hui-c2-table-row">
          <th scope="row">Escaped content</th>
          <td id="hui-c2-hostile-content">{@hostile_content}</td>
        </tr>
      </UI.table>

      <UI.disclosure id="hui-c2-disclosure" mode={:independent}>
        <:item key="native" summary="Native disclosure" open>
          <p id="hui-c2-disclosure-copy">Details remain operable without JavaScript.</p>
        </:item>
      </UI.disclosure>

      <UI.dialog id="hui-c2-dialog" initial_focus={:close}>
        <:trigger>Open primitive dialog</:trigger>
        <:title>Primitive dialog</:title>
        <:description>Native dialog semantics preserve an explicit exit.</:description>
        <p id="hui-c2-dialog-copy">Supplementary dialog content.</p>
        <:close>Close primitive dialog</:close>
        <:fallback>
          <a id="hui-c2-dialog-fallback" href="#hui-c2-dialog-copy">Read dialog content</a>
        </:fallback>
      </UI.dialog>

      <UI.menu id="hui-c2-menu" accessible_label="Primitive actions">
        <:trigger>Open primitive actions</:trigger>
        <:action
          key="details"
          label="View details"
          kind={:link}
          destination="/qualification-only?view=details"
        />
        <:action
          key="reset"
          label="Reset presentation"
          kind={:button}
          type="reset"
          form="hui-c2-form"
        />
        <:fallback>
          <a id="hui-c2-menu-fallback" href="/qualification-only?view=details">
            View actions
          </a>
        </:fallback>
      </UI.menu>

      <UI.tooltip id="hui-c2-tooltip" text="Supplementary presentation guidance">
        <:trigger label="Show primitive guidance" kind={:button} type="button" />
      </UI.tooltip>

      <UI.toast id="hui-c2-toast" kind={:success} title="Catalog rendered">
        Every primitive uses native, escaped markup.
        <:actions>
          <UI.link id="hui-c2-toast-action" href="#hui-c2-primitives-title">Return to title</UI.link>
        </:actions>
      </UI.toast>

      <UI.status id="hui-c2-status" kind={:attention}>
        Review the explicit state label as well as its color.
      </UI.status>

      <div id="hui-c2-loading-region" role="status" aria-label="Loading primitive preview">
        <UI.skeleton id="hui-c2-skeleton" shape={:text} size={:large} />
      </div>
    </section>
    """
  end
end
