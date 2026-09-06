defmodule JidoCodeWeb.StreamHTML do
  use JidoCodeWeb, :html
  alias JidoCodeWeb.Components.UI

  attr :state, :atom, required: true, values: [:revoked, :expired, :closed]

  def terminal(assigns) do
    ~H"""
    <div id="product-shell" data-stream-terminal={@state}>
      <main id="product-main" class="mx-auto grid max-w-3xl gap-6 p-8">
        <h1 class="text-xl font-semibold">Access check required</h1>
        <p id="product-stream-status" role="alert" tabindex="-1">
          This connection ended. Earlier protected content has been cleared.
        </p>
        <UI.link id="product-stream-reload" href="" class="underline underline-offset-4">
          Reload and check access
        </UI.link>
      </main>
    </div>
    """
  end
end
