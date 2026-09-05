defmodule JidoCode.TestSupport.IdentityRecoveryAdapter do
  @behaviour JidoCode.Identity.RecoveryAdapter

  @impl true
  def verify(%{proof: "verified-independent-proof"}, _account) do
    {:ok,
     %{
       method_class: :independent_test_recovery,
       approval_refs: ["recovery-approval-test"]
     }}
  end

  def verify(_evidence, _account), do: {:error, :invalid_recovery}
end
