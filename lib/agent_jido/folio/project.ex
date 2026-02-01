defmodule AgentJido.Folio.Project do
  @moduledoc """
  Project resource for GTD multi-step outcomes.

  Generated modules:
  - `Project.Jido.Create` - create_project
  - `Project.Jido.Read` - list_projects
  - `Project.Jido.MarkDone` - complete_project
  - `Project.Jido.DeferSomeday` - defer_project
  - `Project.Jido.Active` - get_active_projects
  """
  use Ash.Resource,
    domain: AgentJido.Folio,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJido]

  ets do
    private? false
  end

  jido do
    action :create,
      name: "create_project",
      description: "Create a new multi-step project",
      tags: ["folio"]

    action :read,
      name: "list_projects",
      description: "List all projects",
      tags: ["folio"]

    action :mark_done,
      name: "complete_project",
      description: "Mark a project as complete",
      tags: ["folio"]

    action :defer_someday,
      name: "defer_project",
      description: "Move a project to someday/maybe",
      tags: ["folio"]

    action :active,
      name: "get_active_projects",
      description: "Get all active projects",
      tags: ["folio"]
  end

  actions do
    defaults [:read]

    create :create do
      accept [:title, :outcome, :notes]
      change set_attribute(:status, :active)
    end

    update :mark_done do
      accept []
      change set_attribute(:status, :done)
    end

    update :defer_someday do
      accept []
      change set_attribute(:status, :someday)
    end

    read :active do
      filter expr(status == :active)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string, allow_nil?: false, public?: true
    attribute :outcome, :string, public?: true
    attribute :notes, :string, public?: true

    attribute :status, :atom,
      default: :active,
      constraints: [one_of: [:active, :someday, :done, :dropped]],
      public?: true

    timestamps()
  end
end
