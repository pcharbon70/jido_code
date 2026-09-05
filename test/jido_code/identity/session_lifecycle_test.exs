defmodule JidoCode.Identity.SessionLifecycleTest do
  use ExUnit.Case, async: true

  alias JidoCode.Identity.Store

  @credential "correct horse battery staple"

  test "issues only server-side bounded state and enforces idle and hard expiry" do
    store = start_store()
    now = ~U[2026-09-05 12:00:00Z]
    authentication = authenticate(store, now)

    assert {:ok, session} = Store.issue_session(store, authentication, now: now)
    assert session.subject_ref == authentication.subject_ref
    assert session.account_generation == authentication.account_generation
    assert session.hard_expires_at == DateTime.add(now, 600, :second)
    assert session.idle_expires_at == DateTime.add(now, 120, :second)
    refute Map.has_key?(Map.from_struct(session), :credential)
    refute Map.has_key?(Map.from_struct(session), :grant)
    refute Map.has_key?(Map.from_struct(session), :delegation)

    assert {:ok, %{session: touched}} =
             Store.validate_session(store, session.session_ref,
               now: DateTime.add(now, 60, :second)
             )

    assert touched.idle_expires_at == DateTime.add(now, 180, :second)

    assert {:error, :expired} =
             Store.validate_session(store, session.session_ref,
               now: DateTime.add(now, 180, :second)
             )

    authentication = authenticate(store, now)
    assert {:ok, hard_limited} = Store.issue_session(store, authentication, now: now)

    for seconds <- [100, 200, 300, 400, 500] do
      assert {:ok, _current} =
               Store.validate_session(store, hard_limited.session_ref,
                 now: DateTime.add(now, seconds, :second)
               )
    end

    assert {:ok, %{session: nearly_hard_expired}} =
             Store.validate_session(store, hard_limited.session_ref,
               now: DateTime.add(now, 550, :second)
             )

    assert nearly_hard_expired.idle_expires_at == hard_limited.hard_expires_at

    assert {:error, :expired} =
             Store.validate_session(store, hard_limited.session_ref,
               now: DateTime.add(now, 600, :second)
             )
  end

  test "rotates a prior session, rejects fixation, and revokes logout-all generations" do
    store = start_store()
    now = ~U[2026-09-05 12:00:00Z]
    authentication = authenticate(store, now)
    assert {:ok, first} = Store.issue_session(store, authentication, now: now)

    assert {:ok, second} =
             Store.issue_session(store, authentication,
               now: DateTime.add(now, 1, :second),
               replace_session_ref: first.session_ref
             )

    refute first.session_ref == second.session_ref
    refute first.nonce == second.nonce
    assert {:error, :revoked} = Store.validate_session(store, first.session_ref, now: now)

    assert {:ok, _current} =
             Store.validate_session(store, second.session_ref, now: DateTime.add(now, 1, :second))

    assert {:ok, account} = Store.account(store, authentication.subject_ref)

    assert {:ok, next_account} =
             Store.logout_all(
               store,
               %{actor_ref: account.subject_ref},
               account.subject_ref,
               now: DateTime.add(now, 2, :second)
             )

    assert next_account.account_generation == account.account_generation + 1
    assert {:error, :revoked} = Store.validate_session(store, second.session_ref, now: now)
    assert {:error, :authentication_stale} = Store.issue_session(store, authentication, now: now)
  end

  test "requires current authentication age and current subject to revoke" do
    store = start_store()
    now = ~U[2026-09-05 12:00:00Z]
    stale_authentication = authenticate(store, DateTime.add(now, -601, :second))

    assert {:error, :authentication_stale} =
             Store.issue_session(store, stale_authentication, now: now)

    authentication = authenticate(store, now)
    assert {:ok, session} = Store.issue_session(store, authentication, now: now)

    assert {:error, :identity_admin_denied} =
             Store.revoke_session(
               store,
               %{actor_ref: "human_other"},
               session.session_ref,
               now: now
             )

    assert :ok =
             Store.revoke_session(
               store,
               %{actor_ref: authentication.subject_ref},
               session.session_ref,
               now: now
             )

    assert {:error, :revoked} = Store.validate_session(store, session.session_ref, now: now)
  end

  test "emits privacy-safe session telemetry without nonce or credential material" do
    store = start_store()
    parent = self()
    handler = "identity-session-test-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach_many(
        handler,
        [
          [:jido_code, :identity, :session, :issued],
          [:jido_code, :identity, :session, :validated]
        ],
        fn event, measurements, metadata, _config ->
          send(parent, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

    on_exit(fn -> :telemetry.detach(handler) end)
    now = ~U[2026-09-05 12:00:00Z]
    authentication = authenticate(store, now)
    assert {:ok, session} = Store.issue_session(store, authentication, now: now)
    assert {:ok, _current} = Store.validate_session(store, session.session_ref, now: now)

    for expected <- [:issued, :validated] do
      assert_receive {:telemetry, [:jido_code, :identity, :session, ^expected], %{count: 1},
                      metadata}

      refute Map.has_key?(metadata, :nonce)
      refute Map.has_key?(metadata, :credential)
      refute Map.has_key?(metadata, :authenticator)
    end
  end

  defp authenticate(store, now) do
    account = bootstrap(store)
    {:ok, authentication} = Store.authenticate(store, account.login, @credential, now: now)
    authentication
  end

  defp bootstrap(store) do
    case Store.bootstrap(
           store,
           %{display_name: "Ada Lovelace", login: "ada@example.test"},
           @credential,
           local_ceremony: true,
           now: ~U[2026-09-05 11:00:00Z]
         ) do
      {:ok, account} -> account
      {:error, :bootstrap_consumed} -> elem(Store.account(store, subject_ref(store)), 1)
    end
  end

  defp subject_ref(store) do
    {:ok, authentication} =
      Store.authenticate(store, "ada@example.test", @credential, now: ~U[2026-09-05 11:00:00Z])

    authentication.subject_ref
  end

  defp start_store do
    start_supervised!(
      {Store,
       name: nil,
       config: [
         enabled: true,
         persistence: false,
         policy_revision: "hui.identity.test.v1",
         pbkdf2_iterations: 1_000,
         max_failed_attempts: 5,
         lockout_seconds: 300,
         hard_lifetime_seconds: 600,
         idle_lifetime_seconds: 120,
         idle_warning_seconds: 30,
         maximum_authentication_age_seconds: 600,
         bootstrap: nil
       ]}
    )
  end
end
