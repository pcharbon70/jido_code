defmodule JidoCodeWeb.ArchitectureFixture.EffectRoute do
  def route, do: get("/projects/:id/apply", ProjectController, :apply)
end
