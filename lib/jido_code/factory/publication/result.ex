defmodule JidoCode.Factory.Publication.Result do
  @moduledoc "Provider receipt for a bot-branch pull-request publication attempt."

  @enforce_keys [
    :attempt_iri,
    :run_graph_iri,
    :base_branch,
    :bot_branch,
    :old_object,
    :new_object,
    :external_branch_id,
    :external_pull_request_id,
    :provider_revision,
    :credential_scope,
    :merge_authority?,
    :terminal?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
end
