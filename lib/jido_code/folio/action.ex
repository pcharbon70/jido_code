defmodule JidoCode.Folio.Action do
  @moduledoc """
  GTD Action resource for the Folio system.

  Actions represent next steps, waiting-for items, and someday/maybe tasks.
  Supports hierarchical sub-actions via self-referential parent_action_id.

  Generated Jido tools:
  - `Action.Jido.Create` - create_action
  - `Action.Jido.Read` - list_actions
  - `Action.Jido.Complete` - complete_action
  - `Action.Jido.MarkWaiting` - mark_waiting_for
  - `Action.Jido.DeferSomeday` - defer_action
  - `Action.Jido.MakeNext` - activate_action
  - `Action.Jido.AddSubAction` - add_sub_action
  - `Action.Jido.Next` - get_next_actions
  - `Action.Jido.WaitingFor` - get_waiting_for
  """
  use Ash.Resource,
    domain: JidoCode.Folio,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJido]

  ets do
    private? false
  end

  jido do
    action :create,
      name: "create_action",
      description: "Create a new action/next step",
      tags: ["folio"]

    action :read, name: "list_actions", description: "List all actions", tags: ["folio"]
    action :complete, name: "complete_action", description: "Mark action as done", tags: ["folio"]

    action :mark_waiting,
      name: "mark_waiting_for",
      description: "Set action to waiting status with contact",
      tags: ["folio"]

    action :defer_someday,
      name: "defer_action",
      description: "Move action to someday/maybe",
      tags: ["folio"]

    action :make_next,
      name: "activate_action",
      description: "Promote action to next action",
      tags: ["folio"]

    action :add_sub_action,
      name: "add_sub_action",
      description: "Create a child sub-action",
      tags: ["folio"]

    action :next, name: "get_next_actions", description: "Get all next actions", tags: ["folio"]

    action :waiting_for,
      name: "get_waiting_for",
      description: "Get all waiting-for actions",
      tags: ["folio"]
  end

  actions do
    defaults [:read]

    create :create do
      accept [:title, :notes, :due_on, :project_id, :parent_action_id, :position]
      change set_attribute(:status, :next)
    end

    update :complete do
      accept []
      change set_attribute(:status, :done)
    end

    update :mark_waiting do
      accept [:waiting_on]
      change set_attribute(:status, :waiting)
    end

    update :defer_someday do
      accept []
      change set_attribute(:status, :someday)
    end

    update :make_next do
      accept []
      change set_attribute(:status, :next)
    end

    create :add_sub_action do
      accept [:title, :notes, :due_on, :project_id, :position]

      argument :parent_action_id, :uuid, allow_nil?: false

      change set_attribute(:status, :next)
      change set_attribute(:parent_action_id, arg(:parent_action_id))
    end

    read :next do
      filter expr(status == :next)
    end

    read :waiting_for do
      filter expr(status == :waiting)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string, allow_nil?: false, public?: true
    attribute :notes, :string, public?: true

    attribute :status, :atom,
      default: :next,
      constraints: [one_of: [:next, :waiting, :someday, :done, :dropped]],
      public?: true

    attribute :waiting_on, :string, public?: true
    attribute :due_on, :date, public?: true
    attribute :position, :integer, public?: true

    timestamps()
  end

  relationships do
    belongs_to :project, JidoCode.Folio.Project do
      allow_nil? true
      public? true
    end

    belongs_to :parent_action, JidoCode.Folio.Action do
      allow_nil? true
      public? true
    end

    has_many :sub_actions, JidoCode.Folio.Action do
      destination_attribute :parent_action_id
    end
  end
end
