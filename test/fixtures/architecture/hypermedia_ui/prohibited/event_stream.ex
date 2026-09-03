defmodule JidoCodeWeb.ArchitectureFixture.EventOwner do
  def handle_event("save", params, socket), do: {:noreply, stream(socket, :items, [params])}
end
