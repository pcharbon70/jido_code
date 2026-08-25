defmodule JidoCode.TestSupport.FakeManagedCodingControlGateway do
  @moduledoc false

  alias JidoCode.Factory.ManagedCoding.Outcome

  def submit(authority, identity, attempt, operation, params, options) do
    send(Application.fetch_env!(:jido_code, :managed_coding_product_test_pid), {
      :managed_control,
      authority,
      identity,
      attempt,
      operation,
      params,
      options
    })

    Outcome.new(%{
      attempt_iri: attempt.attempt_iri,
      fencing_token: attempt.fencing_token,
      state: if(operation == :cancel, do: :cancelling, else: :running),
      sequence: attempt.sequence + 1,
      occurred_at: ~U[2026-08-25 14:00:00Z],
      references: []
    })
  end
end
