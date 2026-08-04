defmodule JidoCode.Knowledge.Commands.Retention do
  @moduledoc false

  alias JidoCode.Knowledge.Identity
  alias JidoCode.Knowledge.Retention.Plan
  alias JidoCode.Knowledge.WriteBatch

  @spec batch(Plan.t()) :: {:ok, WriteBatch.t()} | {:error, JidoCode.Knowledge.Error.t()}
  def batch(%Plan{} = plan) do
    WriteBatch.new(plan.audit_additions,
      commit_id: Identity.commit_iri(),
      removals: plan.removals,
      expected_dataset_revision: plan.dataset_revision,
      expected_graph_revisions: plan.graph_revisions,
      removal_policy: :maintenance,
      operation_metadata: %{
        operation: :retention,
        plan_id: plan.id,
        checksum: plan.checksum
      }
    )
  end
end
