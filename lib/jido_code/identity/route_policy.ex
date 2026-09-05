defmodule JidoCode.Identity.RoutePolicy do
  @moduledoc "Closed route-area and role-explanation vocabulary for HUI-C1."

  @areas ~w[developer reviewer operations security cost knowledge administration]a
  @actions ~w[page query field stream command export download]a
  @operations ~w[
    factory_shell project_page attempt_page evidence_page operations_page security_page
    cost_page knowledge_page administration_page compatibility_product
  ]a

  @role_areas %{
    observer: [:developer],
    project_developer: [:developer],
    project_maintainer: [:developer, :reviewer],
    independent_verifier: [:reviewer],
    factory_operator: [:operations],
    security_auditor: [:security],
    factory_administrator: [:administration],
    knowledge_steward: [:knowledge],
    cost_observer: [:cost]
  }

  def areas, do: @areas
  def actions, do: @actions
  def operations, do: @operations
  def roles, do: Map.keys(@role_areas)

  @spec explained_areas(atom()) :: [atom()]
  def explained_areas(role), do: Map.get(@role_areas, role, [])

  @spec role_explains_area?(atom(), atom()) :: boolean()
  def role_explains_area?(role, area), do: area in explained_areas(role)
end
