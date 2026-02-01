defmodule AgentJido.Folio do
  use Ash.Domain

  resources do
    resource AgentJido.Folio.InboxItem
    resource AgentJido.Folio.Action
    resource AgentJido.Folio.Project
  end
end
