defmodule JidoCode.Identity.AccountLifecycleTest do
  use ExUnit.Case, async: true

  alias JidoCode.Identity.Store
  alias JidoCode.TestSupport.Filesystem
  alias JidoCode.TestSupport.IdentityRecoveryAdapter

  @credential "correct horse battery staple"
  @next_credential "another long credential value"

  test "bootstraps one immutable named subject and keeps verifier material private" do
    store = start_store()
    assert {:ok, account} = bootstrap(store)

    assert account.subject_ref =~ ~r/^human_[A-Za-z0-9_-]+$/
    assert account.display_name == "Ada Lovelace"
    assert account.login == "ada@example.test"
    assert account.status == :active
    assert account.account_generation == 1
    refute Map.has_key?(Map.from_struct(account), :credential)
    refute inspect(account) =~ @credential

    [authenticator_ref] = account.authenticator_refs
    assert {:ok, authenticator} = Store.authenticator(store, authenticator_ref)
    assert authenticator.subject_ref == account.subject_ref
    assert authenticator.kind == :local_password
    refute authenticator.phishing_resistant
    refute Map.has_key?(Map.from_struct(authenticator), :verifier)

    assert {:error, :bootstrap_consumed} = bootstrap(store)

    assert {:ok, authentication} =
             Store.authenticate(store, "ADA@example.test", @credential)

    assert authentication.subject_ref == account.subject_ref
    assert authentication.assurance == :baseline
    refute Map.has_key?(authentication, :credential)

    assert [%{outcome: :succeeded, subject_ref: subject_ref}] =
             Store.evidence(store, :authentication)

    assert subject_ref == account.subject_ref

    assert [%{action_ref: "identity.bootstrap", outcome: :committed}] =
             Store.evidence(store, :audit)
  end

  test "returns safe authentication failures and enforces bounded lockout" do
    store = start_store(max_failed_attempts: 3, lockout_seconds: 60)
    assert {:ok, account} = bootstrap(store)
    now = ~U[2026-09-05 12:00:00Z]

    for _attempt <- 1..3 do
      assert {:error, :authentication_failed} =
               Store.authenticate(store, account.login, "incorrect value", now: now)
    end

    assert {:error, :authentication_failed} =
             Store.authenticate(store, account.login, @credential,
               now: DateTime.add(now, 59, :second)
             )

    assert {:ok, _authentication} =
             Store.authenticate(store, account.login, @credential,
               now: DateTime.add(now, 60, :second)
             )

    assert {:error, :authentication_failed} =
             Store.authenticate(store, "unknown@example.test", "incorrect value", now: now)

    events = Store.evidence(store, :authentication)
    assert Enum.all?(events, &(not Map.has_key?(Map.from_struct(&1), :credential)))
    assert Enum.any?(events, &(&1.subject_ref == "human_unknown"))
  end

  test "rotates credentials and generations, supports logout-all, and disables safely" do
    store = start_store()
    assert {:ok, account} = bootstrap(store)

    assert {:ok, rotated} =
             Store.rotate_credential(
               store,
               %{subject_ref: account.subject_ref},
               account.subject_ref,
               @credential,
               @next_credential
             )

    assert rotated.account_generation == 2

    assert {:error, :authentication_failed} =
             Store.authenticate(store, account.login, @credential)

    assert {:ok, _authentication} =
             Store.authenticate(store, account.login, @next_credential)

    assert {:ok, logged_out} =
             Store.logout_all(
               store,
               %{actor_ref: account.subject_ref},
               account.subject_ref
             )

    assert logged_out.account_generation == 3

    admin = %{
      source: :governed_identity_admin,
      actor_ref: "human_independent_admin",
      assurance: :action_bound_step_up
    }

    assert {:error, :identity_admin_denied} =
             Store.disable_account(
               store,
               %{source: :browser_role, actor_ref: "attacker", assurance: :action_bound_step_up},
               account.subject_ref
             )

    assert {:ok, disabled} = Store.disable_account(store, admin, account.subject_ref)
    assert disabled.status == :disabled
    assert disabled.account_generation == 4

    assert {:error, :authentication_failed} =
             Store.authenticate(store, account.login, @next_credential)
  end

  test "makes stronger assurance and unconfigured recovery explicitly unavailable" do
    store = start_store()
    assert {:ok, account} = bootstrap(store)

    assert %{phishing_resistant: false, step_up: :unavailable, recovery: :unavailable} =
             Store.capabilities(store)

    assert {:error, :step_up_unavailable} =
             Store.authenticate(store, account.login, @credential,
               minimum_assurance: :phishing_resistant
             )

    context = %{source: :independent_recovery, initiator_ref: "human_recovery_operator"}

    assert {:error, :recovery_unavailable} =
             Store.recover_account(
               store,
               context,
               account.subject_ref,
               @next_credential,
               %{proof: "anything"}
             )
  end

  test "accepts only independent recovery evidence and revokes prior generations" do
    store = start_store(recovery_adapter: IdentityRecoveryAdapter)
    assert {:ok, account} = bootstrap(store)

    context = %{source: :independent_recovery, initiator_ref: "human_recovery_operator"}

    assert {:error, :invalid_recovery} =
             Store.recover_account(
               store,
               context,
               account.subject_ref,
               @next_credential,
               %{proof: "invalid"}
             )

    assert {:error, :recovery_denied} =
             Store.recover_account(
               store,
               %{source: :independent_recovery, initiator_ref: account.subject_ref},
               account.subject_ref,
               @next_credential,
               %{proof: "verified-independent-proof"}
             )

    assert {:ok, recovered} =
             Store.recover_account(
               store,
               context,
               account.subject_ref,
               @next_credential,
               %{proof: "verified-independent-proof"}
             )

    assert recovered.account_generation == 2

    assert {:ok, _authentication} =
             Store.authenticate(store, account.login, @next_credential)

    assert [event] = Store.evidence(store, :recovery)
    assert event.generation_before == 1
    assert event.generation_after == 2
    assert event.approval_refs == ["recovery-approval-test"]
  end

  test "persists an integrity-protected snapshot and rejects tampering" do
    root =
      Path.join(System.tmp_dir!(), "jido-code-identity-#{System.unique_integer([:positive])}")

    path = Path.join(root, "identity.snapshot")
    on_exit(fn -> Filesystem.remove_root!(root) end)
    key = :crypto.strong_rand_bytes(32)

    {:ok, store} =
      Store.start_link(
        name: nil,
        config: config(persistence: true, path: path, integrity_key: key)
      )

    assert {:ok, account} = bootstrap(store)
    GenServer.stop(store)

    assert {:ok, restored} =
             Store.start_link(
               name: nil,
               config: config(persistence: true, path: path, integrity_key: key)
             )

    assert {:ok, ^account} = Store.account(restored, account.subject_ref)
    GenServer.stop(restored)

    :ok = File.write(path, File.read!(path) <> "tamper")

    prior_trap_exit = Process.flag(:trap_exit, true)
    on_exit(fn -> Process.flag(:trap_exit, prior_trap_exit) end)

    assert {:error, :identity_store_integrity_failed} =
             Store.start_link(
               name: nil,
               config: config(persistence: true, path: path, integrity_key: key)
             )
  end

  defp start_store(overrides \\ []) do
    start_supervised!({Store, name: nil, config: config(overrides)})
  end

  defp bootstrap(store) do
    Store.bootstrap(
      store,
      %{display_name: "Ada Lovelace", login: "ada@example.test"},
      @credential,
      local_ceremony: true
    )
  end

  defp config(overrides) do
    Keyword.merge(
      [
        enabled: true,
        persistence: false,
        path: nil,
        integrity_key: nil,
        policy_revision: "hui.identity.test.v1",
        pbkdf2_iterations: 1_000,
        max_failed_attempts: 5,
        lockout_seconds: 300,
        recovery_adapter: JidoCode.Identity.Recovery.Unconfigured,
        bootstrap: nil
      ],
      overrides
    )
  end
end
