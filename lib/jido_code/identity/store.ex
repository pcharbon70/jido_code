defmodule JidoCode.Identity.Store do
  @moduledoc """
  Exclusive server-side authority for named accounts and authenticators.

  Public identity records are kept separate from salted credential verifiers.
  When persistence is enabled, the complete snapshot is integrity protected,
  written atomically, and restricted to the owning operating-system account.
  """

  use GenServer

  alias JidoCode.Identity.AuditEvent
  alias JidoCode.Identity.AuthenticationEvent
  alias JidoCode.Identity.Authenticator
  alias JidoCode.Identity.BrowserSession
  alias JidoCode.Identity.Config
  alias JidoCode.Identity.Credential
  alias JidoCode.Identity.HumanAccount
  alias JidoCode.Identity.RecoveryEvent

  @snapshot_version 1
  @architecture_file_role :identity_authority
  @unknown_subject "human_unknown"
  @allowed_assurance [:baseline, :phishing_resistant, :action_bound_step_up]

  defstruct [:config, :data]

  @type server :: GenServer.server()

  @doc false
  def architecture_file_role, do: @architecture_file_role

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec bootstrap(server(), map(), String.t(), keyword()) ::
          {:ok, HumanAccount.t()} | {:error, atom()}
  def bootstrap(server \\ __MODULE__, attributes, credential, options \\ []) do
    GenServer.call(server, {:bootstrap, attributes, credential, options}, 30_000)
  end

  @spec authenticate(server(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def authenticate(server \\ __MODULE__, login, credential, options \\ []) do
    GenServer.call(server, {:authenticate, login, credential, options}, 30_000)
  end

  @spec account(server(), String.t()) :: {:ok, HumanAccount.t()} | {:error, :not_found}
  def account(server \\ __MODULE__, subject_ref) do
    GenServer.call(server, {:account, subject_ref})
  end

  @spec authenticator(server(), String.t()) ::
          {:ok, Authenticator.t()} | {:error, :not_found}
  def authenticator(server \\ __MODULE__, authenticator_ref) do
    GenServer.call(server, {:authenticator, authenticator_ref})
  end

  @spec rotate_credential(server(), map(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, HumanAccount.t()} | {:error, atom()}
  def rotate_credential(
        server \\ __MODULE__,
        context,
        subject_ref,
        current_credential,
        next_credential,
        options \\ []
      ) do
    GenServer.call(
      server,
      {:rotate_credential, context, subject_ref, current_credential, next_credential, options},
      30_000
    )
  end

  @spec disable_account(server(), map(), String.t(), keyword()) ::
          {:ok, HumanAccount.t()} | {:error, atom()}
  def disable_account(server \\ __MODULE__, context, subject_ref, options \\ []) do
    GenServer.call(server, {:disable_account, context, subject_ref, options})
  end

  @spec logout_all(server(), map(), String.t(), keyword()) ::
          {:ok, HumanAccount.t()} | {:error, atom()}
  def logout_all(server \\ __MODULE__, context, subject_ref, options \\ []) do
    GenServer.call(server, {:logout_all, context, subject_ref, options})
  end

  @spec recover_account(server(), map(), String.t(), String.t(), map(), keyword()) ::
          {:ok, HumanAccount.t()} | {:error, atom()}
  def recover_account(
        server \\ __MODULE__,
        context,
        subject_ref,
        next_credential,
        evidence,
        options \\ []
      ) do
    GenServer.call(
      server,
      {:recover_account, context, subject_ref, next_credential, evidence, options},
      30_000
    )
  end

  @spec evidence(server(), :authentication | :recovery | :audit) :: [struct()]
  def evidence(server \\ __MODULE__, kind), do: GenServer.call(server, {:evidence, kind})

  @spec capabilities(server()) :: map()
  def capabilities(server \\ __MODULE__), do: GenServer.call(server, :capabilities)

  @spec issue_session(server(), map(), keyword()) ::
          {:ok, BrowserSession.t()} | {:error, atom()}
  def issue_session(server \\ __MODULE__, authentication, options \\ []) do
    GenServer.call(server, {:issue_session, authentication, options})
  end

  @spec validate_session(server(), String.t(), keyword()) :: {:ok, map()} | {:error, atom()}
  def validate_session(server \\ __MODULE__, session_ref, options \\ []) do
    GenServer.call(server, {:validate_session, session_ref, options})
  end

  @spec revoke_session(server(), map(), String.t(), keyword()) :: :ok | {:error, atom()}
  def revoke_session(server \\ __MODULE__, context, session_ref, options \\ []) do
    GenServer.call(server, {:revoke_session, context, session_ref, options})
  end

  @impl true
  def init(options) do
    with {:ok, config} <- Config.load(Keyword.get(options, :config, [])),
         {:ok, data} <- load_snapshot(config),
         {:ok, data} <- seed_bootstrap(config, data) do
      {:ok, %__MODULE__{config: config, data: data}}
    else
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_call(:capabilities, _from, state) do
    capabilities = %{
      enabled: state.config.enabled?,
      authenticator: :local_password,
      assurance: :baseline,
      phishing_resistant: false,
      step_up: :unavailable,
      recovery:
        if(state.config.recovery_adapter == JidoCode.Identity.Recovery.Unconfigured,
          do: :unavailable,
          else: :configured
        )
    }

    {:reply, capabilities, state}
  end

  def handle_call({:account, subject_ref}, _from, state) do
    {:reply, fetch(state.data.accounts, subject_ref), state}
  end

  def handle_call({:authenticator, authenticator_ref}, _from, state) do
    {:reply, fetch(state.data.authenticators, authenticator_ref), state}
  end

  def handle_call({:evidence, kind}, _from, state) do
    evidence = Map.get(state.data.events, kind, []) |> Enum.reverse()
    {:reply, evidence, state}
  end

  def handle_call({:issue_session, authentication, options}, _from, state) do
    with :ok <- available(state),
         {:ok, account} <- authenticated_account(state.data, authentication),
         {:ok, authenticated_at} <- fetch_datetime(authentication, :authenticated_at),
         {:ok, assurance} <- fetch_assurance(authentication),
         :ok <- current_authentication_age(authenticated_at, now(options), state.config) do
      issued_at = now(options)
      hard_expires_at = DateTime.add(issued_at, state.config.hard_lifetime_seconds, :second)

      session = %BrowserSession{
        session_ref: reference("session"),
        subject_ref: account.subject_ref,
        issued_at: issued_at,
        last_seen_at: issued_at,
        last_authenticated_at: authenticated_at,
        assurance: assurance,
        nonce: reference("nonce"),
        session_generation: 1,
        account_generation: account.account_generation,
        policy_revision: account.policy_revision,
        hard_expires_at: hard_expires_at,
        idle_expires_at:
          earliest(
            DateTime.add(issued_at, state.config.idle_lifetime_seconds, :second),
            hard_expires_at
          ),
        status: :active,
        revoked_at: nil
      }

      next_data =
        state.data
        |> revoke_prior_session(
          authentication,
          Keyword.get(options, :replace_session_ref),
          issued_at
        )
        |> put_in([:sessions, session.session_ref], session)
        |> append_audit(
          audit_event(
            account.subject_ref,
            "identity.session.issue",
            session.session_ref,
            :committed,
            account.policy_revision,
            reference("identity_receipt"),
            issued_at
          )
        )

      emit_session_telemetry(:issued, session, :allowed)
      commit(state, next_data, {:ok, session})
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:validate_session, session_ref, options}, _from, state) do
    now = now(options)

    with :ok <- available(state),
         {:ok, session} <- fetch(state.data.sessions, session_ref),
         {:ok, account} <- fetch(state.data.accounts, session.subject_ref),
         :ok <- current_session(session, account, now, state.config) do
      touched = touch_session(session, now, state.config)
      next_data = put_in(state.data, [:sessions, session_ref], touched)
      emit_session_telemetry(:validated, touched, :allowed)
      commit(state, next_data, {:ok, %{session: touched, account: account}})
    else
      {:error, reason} ->
        {next_data, safe_reason} = expire_or_revoke_session(state.data, session_ref, now, reason)

        case persist(state.config, next_data) do
          :ok ->
            emit_session_telemetry(:validation_failed, session_ref, safe_reason)
            {:reply, {:error, safe_reason}, %{state | data: next_data}}

          {:error, _persist_reason} ->
            {:reply, {:error, :session_unavailable}, state}
        end
    end
  end

  def handle_call({:revoke_session, context, session_ref, options}, _from, state) do
    with :ok <- available(state),
         {:ok, session} <- fetch(state.data.sessions, session_ref),
         :ok <- session_revoke_context(context, session) do
      now = now(options)
      next_session = revoke(session, now)

      next_data =
        state.data
        |> put_in([:sessions, session_ref], next_session)
        |> append_audit(
          audit_event(
            context.actor_ref,
            "identity.session.revoke",
            session_ref,
            :committed,
            session.policy_revision,
            reference("identity_receipt"),
            now
          )
        )

      emit_session_telemetry(:revoked, next_session, :revoked)
      commit(state, next_data, :ok)
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:bootstrap, attributes, credential, options}, _from, state) do
    with :ok <- available(state),
         :ok <- local_bootstrap(options),
         :ok <- bootstrap_available(state.data),
         {:ok, normalized} <- validate_account_attributes(attributes),
         {:ok, verifier} <- Credential.build(credential, state.config.pbkdf2_iterations) do
      now = now(options)
      subject_ref = reference("human")
      authenticator_ref = reference("authenticator")

      account = %HumanAccount{
        subject_ref: subject_ref,
        display_name: normalized.display_name,
        login: normalized.login,
        status: :active,
        account_generation: 1,
        policy_revision: state.config.policy_revision,
        recovery_state: recovery_state(state.config),
        authenticator_refs: [authenticator_ref],
        inserted_at: now,
        updated_at: now
      }

      authenticator = %Authenticator{
        authenticator_ref: authenticator_ref,
        subject_ref: subject_ref,
        kind: :local_password,
        phishing_resistant: false,
        enrolled_at: now,
        verified_at: now,
        revoked_at: nil,
        status: :active,
        revision: 1
      }

      receipt_ref = reference("identity_receipt")

      next_data =
        state.data
        |> put_in([:accounts, subject_ref], account)
        |> put_in([:login_index, normalized.login], subject_ref)
        |> put_in([:authenticators, authenticator_ref], authenticator)
        |> put_in([:verifiers, authenticator_ref], verifier)
        |> Map.put(:bootstrap_consumed, true)
        |> append_audit(
          audit_event(
            subject_ref,
            "identity.bootstrap",
            subject_ref,
            :committed,
            state.config.policy_revision,
            receipt_ref,
            now
          )
        )

      commit(state, next_data, {:ok, account})
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:authenticate, login, credential, options}, _from, state) do
    with :ok <- available(state),
         {:ok, normalized_login} <- normalize_login(login),
         {:ok, minimum_assurance} <- minimum_assurance(options) do
      authenticate_current(state, normalized_login, credential, minimum_assurance, options)
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(
        {:rotate_credential, context, subject_ref, current_credential, next_credential, options},
        _from,
        state
      ) do
    with :ok <- available(state),
         {:ok, account} <- fetch(state.data.accounts, subject_ref),
         :ok <- self_service_context(context, subject_ref),
         :ok <- active_account(account),
         {:ok, authenticator, verifier} <- active_authenticator(state.data, account),
         true <- Credential.verify(current_credential, verifier),
         {:ok, next_verifier} <-
           Credential.build(next_credential, state.config.pbkdf2_iterations) do
      now = now(options)

      next_authenticator = %{
        authenticator
        | revision: authenticator.revision + 1,
          verified_at: now
      }

      next_account = advance_generation(account, now)
      receipt_ref = reference("identity_receipt")

      next_data =
        state.data
        |> put_in([:accounts, subject_ref], next_account)
        |> put_in([:authenticators, authenticator.authenticator_ref], next_authenticator)
        |> put_in([:verifiers, authenticator.authenticator_ref], next_verifier)
        |> revoke_subject_sessions(subject_ref, now)
        |> append_audit(
          audit_event(
            subject_ref,
            "identity.credential.rotate",
            subject_ref,
            :committed,
            state.config.policy_revision,
            receipt_ref,
            now
          )
        )

      commit(state, next_data, {:ok, next_account})
    else
      false -> {:reply, {:error, :authentication_failed}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:disable_account, context, subject_ref, options}, _from, state) do
    with :ok <- available(state),
         :ok <- identity_admin_context(context),
         {:ok, account} <- fetch(state.data.accounts, subject_ref),
         :ok <- active_account(account) do
      now = now(options)
      next_account = %{advance_generation(account, now) | status: :disabled}
      receipt_ref = reference("identity_receipt")

      next_data =
        state.data
        |> put_in([:accounts, subject_ref], next_account)
        |> revoke_subject_sessions(subject_ref, now)
        |> append_audit(
          audit_event(
            context.actor_ref,
            "identity.account.disable",
            subject_ref,
            :committed,
            state.config.policy_revision,
            receipt_ref,
            now
          )
        )

      commit(state, next_data, {:ok, next_account})
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:logout_all, context, subject_ref, options}, _from, state) do
    with :ok <- available(state),
         {:ok, account} <- fetch(state.data.accounts, subject_ref),
         :ok <- logout_context(context, subject_ref) do
      now = now(options)
      next_account = advance_generation(account, now)
      receipt_ref = reference("identity_receipt")

      next_data =
        state.data
        |> put_in([:accounts, subject_ref], next_account)
        |> revoke_subject_sessions(subject_ref, now)
        |> append_audit(
          audit_event(
            context.actor_ref,
            "identity.session.logout_all",
            subject_ref,
            :committed,
            state.config.policy_revision,
            receipt_ref,
            now
          )
        )

      commit(state, next_data, {:ok, next_account})
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(
        {:recover_account, context, subject_ref, next_credential, evidence, options},
        _from,
        state
      ) do
    with :ok <- available(state),
         {:ok, account} <- fetch(state.data.accounts, subject_ref),
         :ok <- recovery_context(context, subject_ref),
         {:ok, recovery} <- state.config.recovery_adapter.verify(evidence, account),
         {:ok, next_verifier} <-
           Credential.build(next_credential, state.config.pbkdf2_iterations),
         {:ok, authenticator, _prior_verifier} <- active_authenticator(state.data, account) do
      now = now(options)
      generation_before = account.account_generation
      next_account = %{advance_generation(account, now) | status: :active, recovery_state: :ready}

      next_authenticator = %{
        authenticator
        | revision: authenticator.revision + 1,
          verified_at: now
      }

      receipt_ref = reference("identity_receipt")

      recovery_event = %RecoveryEvent{
        recovery_event_ref: reference("recovery_event"),
        initiator_ref: context.initiator_ref,
        subject_ref: subject_ref,
        method_class: recovery.method_class,
        approval_refs: recovery.approval_refs,
        outcome: :committed,
        generation_before: generation_before,
        generation_after: next_account.account_generation,
        occurred_at: now
      }

      next_data =
        state.data
        |> put_in([:accounts, subject_ref], next_account)
        |> put_in([:authenticators, authenticator.authenticator_ref], next_authenticator)
        |> put_in([:verifiers, authenticator.authenticator_ref], next_verifier)
        |> revoke_subject_sessions(subject_ref, now)
        |> append_event(:recovery, recovery_event)
        |> append_audit(
          audit_event(
            context.initiator_ref,
            "identity.account.recover",
            subject_ref,
            :committed,
            state.config.policy_revision,
            receipt_ref,
            now
          )
        )

      commit(state, next_data, {:ok, next_account})
    else
      {:error, :unavailable} -> {:reply, {:error, :recovery_unavailable}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  defp authenticate_current(state, login, credential, minimum_assurance, options) do
    now = now(options)
    subject_ref = Map.get(state.data.login_index, login, @unknown_subject)
    account = Map.get(state.data.accounts, subject_ref)
    locked? = locked?(state.data.failures, login, now)

    result =
      with %HumanAccount{} = account <- account,
           false <- locked?,
           :ok <- active_account(account),
           {:ok, authenticator, verifier} <- active_authenticator(state.data, account),
           true <- Credential.verify(credential, verifier),
           :ok <- assurance_available(authenticator, minimum_assurance) do
        {:ok, account, authenticator}
      else
        nil -> {:error, :authentication_failed}
        true -> {:error, :authentication_failed}
        false -> {:error, :authentication_failed}
        {:error, :step_up_unavailable} -> {:error, :step_up_unavailable}
        {:error, _reason} -> {:error, :authentication_failed}
      end

    if account == nil do
      Credential.dummy_verify(credential, state.config.pbkdf2_iterations)
    end

    authentication_transition(state, login, subject_ref, result, now, options)
  end

  defp authentication_transition(state, login, subject_ref, result, now, options) do
    correlation_ref = Keyword.get(options, :correlation_ref, reference("correlation"))

    {reply, next_failures, outcome, assurance, event_subject} =
      case result do
        {:ok, account, authenticator} ->
          authentication = %{
            subject_ref: account.subject_ref,
            authenticator_ref: authenticator.authenticator_ref,
            assurance: :baseline,
            authenticated_at: now,
            account_generation: account.account_generation,
            policy_revision: account.policy_revision
          }

          {{:ok, authentication}, Map.delete(state.data.failures, login), :succeeded, :baseline,
           account.subject_ref}

        {:error, :step_up_unavailable} ->
          {{:error, :step_up_unavailable}, state.data.failures, :unavailable, :baseline,
           subject_ref}

        {:error, _reason} ->
          failures = record_failure(state.data.failures, login, now, state.config)
          {{:error, :authentication_failed}, failures, :failed, :baseline, subject_ref}
      end

    event = %AuthenticationEvent{
      authentication_event_ref: reference("authentication_event"),
      subject_ref: event_subject,
      method_class: :local_password,
      assurance: assurance,
      outcome: outcome,
      occurred_at: now,
      correlation_ref: correlation_ref,
      policy_revision: state.config.policy_revision
    }

    next_data =
      state.data
      |> Map.put(:failures, next_failures)
      |> append_event(:authentication, event)

    commit(state, next_data, reply)
  end

  defp commit(state, next_data, reply) do
    case persist(state.config, next_data) do
      :ok -> {:reply, reply, %{state | data: next_data}}
      {:error, _reason} -> {:reply, {:error, :identity_store_unavailable}, state}
    end
  end

  defp available(%__MODULE__{config: %Config{enabled?: true}}), do: :ok
  defp available(_state), do: {:error, :authenticator_unavailable}

  defp local_bootstrap(options) do
    if Keyword.get(options, :local_ceremony, false), do: :ok, else: {:error, :bootstrap_denied}
  end

  defp bootstrap_available(%{bootstrap_consumed: false, accounts: accounts})
       when map_size(accounts) == 0,
       do: :ok

  defp bootstrap_available(_data), do: {:error, :bootstrap_consumed}

  defp validate_account_attributes(attributes) when is_map(attributes) do
    with display_name when is_binary(display_name) <- attributes[:display_name],
         true <- byte_size(String.trim(display_name)) in 1..120,
         {:ok, login} <- normalize_login(attributes[:login]) do
      {:ok, %{display_name: String.trim(display_name), login: login}}
    else
      _invalid -> {:error, :invalid_account}
    end
  end

  defp validate_account_attributes(_attributes), do: {:error, :invalid_account}

  defp normalize_login(login) when is_binary(login) do
    normalized = login |> String.trim() |> String.downcase()

    if byte_size(normalized) in 3..254 and Regex.match?(~r/^[a-z0-9][a-z0-9._@+-]+$/, normalized) do
      {:ok, normalized}
    else
      {:error, :invalid_login}
    end
  end

  defp normalize_login(_login), do: {:error, :invalid_login}

  defp minimum_assurance(options) do
    value = Keyword.get(options, :minimum_assurance, :baseline)
    if value in @allowed_assurance, do: {:ok, value}, else: {:error, :invalid_assurance}
  end

  defp assurance_available(_authenticator, :baseline), do: :ok
  defp assurance_available(%Authenticator{phishing_resistant: true}, :phishing_resistant), do: :ok
  defp assurance_available(_authenticator, _minimum), do: {:error, :step_up_unavailable}

  defp active_account(%HumanAccount{status: :active}), do: :ok
  defp active_account(_account), do: {:error, :account_inactive}

  defp active_authenticator(data, account) do
    account.authenticator_refs
    |> Enum.find_value(fn authenticator_ref ->
      authenticator = Map.get(data.authenticators, authenticator_ref)
      verifier = Map.get(data.verifiers, authenticator_ref)

      if match?(%Authenticator{status: :active}, authenticator) and is_map(verifier),
        do: {authenticator, verifier}
    end)
    |> case do
      {%Authenticator{} = authenticator, verifier} -> {:ok, authenticator, verifier}
      nil -> {:error, :authenticator_unavailable}
    end
  end

  defp authenticated_account(data, authentication) when is_map(authentication) do
    with subject_ref when is_binary(subject_ref) <- authentication[:subject_ref],
         {:ok, account} <- fetch(data.accounts, subject_ref),
         :ok <- active_account(account),
         true <- authentication[:account_generation] == account.account_generation,
         true <- authentication[:policy_revision] == account.policy_revision do
      {:ok, account}
    else
      _invalid -> {:error, :authentication_stale}
    end
  end

  defp authenticated_account(_data, _authentication), do: {:error, :authentication_stale}

  defp fetch_datetime(map, key) do
    case map[key] do
      %DateTime{} = value -> {:ok, value}
      _invalid -> {:error, :authentication_stale}
    end
  end

  defp fetch_assurance(authentication) do
    case authentication[:assurance] do
      assurance when assurance in @allowed_assurance -> {:ok, assurance}
      _invalid -> {:error, :authentication_stale}
    end
  end

  defp current_authentication_age(authenticated_at, now, config) do
    age = DateTime.diff(now, authenticated_at, :second)

    if age in 0..config.maximum_authentication_age_seconds,
      do: :ok,
      else: {:error, :authentication_stale}
  end

  defp current_session(session, account, now, config) do
    cond do
      session.status != :active ->
        {:error, :revoked}

      account.status != :active ->
        {:error, :revoked}

      session.account_generation != account.account_generation ->
        {:error, :revoked}

      session.policy_revision != account.policy_revision ->
        {:error, :revoked}

      DateTime.compare(now, session.issued_at) == :lt ->
        {:error, :invalid_session}

      DateTime.compare(now, session.hard_expires_at) != :lt ->
        {:error, :expired}

      DateTime.compare(now, session.idle_expires_at) != :lt ->
        {:error, :expired}

      DateTime.diff(now, session.last_authenticated_at, :second) >
          config.maximum_authentication_age_seconds ->
        {:error, :expired}

      true ->
        :ok
    end
  end

  defp touch_session(session, now, config) do
    idle_expires_at =
      now
      |> DateTime.add(config.idle_lifetime_seconds, :second)
      |> earliest(session.hard_expires_at)

    %{session | last_seen_at: now, idle_expires_at: idle_expires_at}
  end

  defp expire_or_revoke_session(data, session_ref, now, reason) do
    safe_reason = if reason == :expired, do: :expired, else: :revoked

    case Map.get(data.sessions, session_ref) do
      %BrowserSession{} = session ->
        status = if safe_reason == :expired, do: :expired, else: :revoked
        next = %{session | status: status, revoked_at: now}
        {put_in(data, [:sessions, session_ref], next), safe_reason}

      _missing ->
        {data, :invalid_session}
    end
  end

  defp revoke_prior_session(data, authentication, session_ref, now) when is_binary(session_ref) do
    case Map.get(data.sessions, session_ref) do
      %BrowserSession{subject_ref: subject_ref} = session
      when subject_ref == authentication.subject_ref ->
        put_in(data, [:sessions, session_ref], revoke(session, now))

      _unknown_or_cross_subject ->
        data
    end
  end

  defp revoke_prior_session(data, _authentication, _session_ref, _now), do: data

  defp revoke_subject_sessions(data, subject_ref, now) do
    sessions =
      Map.new(data.sessions, fn {session_ref, session} ->
        if session.subject_ref == subject_ref,
          do: {session_ref, revoke(session, now)},
          else: {session_ref, session}
      end)

    %{data | sessions: sessions}
  end

  defp revoke(%BrowserSession{} = session, now),
    do: %{session | status: :revoked, revoked_at: now}

  defp session_revoke_context(%{actor_ref: actor_ref}, %{subject_ref: actor_ref}), do: :ok

  defp session_revoke_context(context, session),
    do: identity_admin_context_for(context, session.subject_ref)

  defp earliest(left, right) do
    if DateTime.compare(left, right) == :gt, do: right, else: left
  end

  defp emit_session_telemetry(event, %BrowserSession{} = session, outcome) do
    :telemetry.execute(
      [:jido_code, :identity, :session, event],
      %{count: 1},
      %{
        subject_ref: session.subject_ref,
        session_ref: session.session_ref,
        outcome: outcome,
        assurance: session.assurance,
        policy_revision: session.policy_revision
      }
    )
  end

  defp emit_session_telemetry(event, _unknown_ref, outcome) do
    :telemetry.execute(
      [:jido_code, :identity, :session, event],
      %{count: 1},
      %{outcome: outcome}
    )
  end

  defp self_service_context(%{subject_ref: subject_ref}, subject_ref), do: :ok
  defp self_service_context(_context, _subject_ref), do: {:error, :identity_mismatch}

  defp logout_context(%{actor_ref: subject_ref}, subject_ref), do: :ok
  defp logout_context(context, subject_ref), do: identity_admin_context_for(context, subject_ref)

  defp identity_admin_context(%{
         source: :governed_identity_admin,
         actor_ref: actor_ref,
         assurance: :action_bound_step_up
       })
       when is_binary(actor_ref),
       do: :ok

  defp identity_admin_context(_context), do: {:error, :identity_admin_denied}

  defp identity_admin_context_for(context, _subject_ref), do: identity_admin_context(context)

  defp recovery_context(
         %{
           source: :independent_recovery,
           initiator_ref: initiator_ref
         },
         subject_ref
       )
       when is_binary(initiator_ref) and initiator_ref != subject_ref,
       do: :ok

  defp recovery_context(_context, _subject_ref), do: {:error, :recovery_denied}

  defp advance_generation(account, now) do
    %{account | account_generation: account.account_generation + 1, updated_at: now}
  end

  defp locked?(failures, login, now) do
    case Map.get(failures, login) do
      %{locked_until: %DateTime{} = locked_until} -> DateTime.compare(now, locked_until) == :lt
      _missing -> false
    end
  end

  defp record_failure(failures, login, now, config) do
    current = Map.get(failures, login, %{count: 0, locked_until: nil})
    count = current.count + 1

    locked_until =
      cond do
        match?(%DateTime{}, current.locked_until) -> current.locked_until
        count >= config.max_failed_attempts -> DateTime.add(now, config.lockout_seconds, :second)
        true -> nil
      end

    Map.put(failures, login, %{count: count, locked_until: locked_until})
  end

  defp recovery_state(%Config{recovery_adapter: JidoCode.Identity.Recovery.Unconfigured}),
    do: :not_configured

  defp recovery_state(_config), do: :ready

  defp audit_event(actor_ref, action_ref, object_ref, outcome, policy, receipt_ref, now) do
    %AuditEvent{
      audit_event_ref: reference("audit_event"),
      actor_ref: actor_ref,
      action_ref: action_ref,
      object_ref: object_ref,
      outcome: outcome,
      policy_revision: policy,
      receipt_ref: receipt_ref,
      occurred_at: now
    }
  end

  defp append_audit(data, event), do: append_event(data, :audit, event)

  defp append_event(data, kind, event) do
    update_in(data, [:events, kind], &[event | &1])
  end

  defp reference(prefix) do
    suffix = Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
    prefix <> "_" <> suffix
  end

  defp now(options), do: Keyword.get(options, :now, DateTime.utc_now())

  defp fetch(map, key) when is_binary(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, :not_found}
    end
  end

  defp fetch(_map, _key), do: {:error, :not_found}

  defp initial_data do
    %{
      accounts: %{},
      login_index: %{},
      authenticators: %{},
      verifiers: %{},
      sessions: %{},
      failures: %{},
      events: %{authentication: [], recovery: [], audit: []},
      bootstrap_consumed: false
    }
  end

  defp load_snapshot(%Config{persistence?: false}), do: {:ok, initial_data()}

  defp load_snapshot(%Config{} = config) do
    case File.read(config.path) do
      {:ok, encoded} -> decode_snapshot(encoded, config.integrity_key)
      {:error, :enoent} -> {:ok, initial_data()}
      {:error, _reason} -> {:error, :identity_store_unavailable}
    end
  end

  defp decode_snapshot(encoded, integrity_key) do
    with {%{version: @snapshot_version, data: data, mac: mac}, used}
         when used == byte_size(encoded) and is_binary(data) and is_binary(mac) <-
           :erlang.binary_to_term(encoded, [:safe, :used]),
         expected <- :crypto.mac(:hmac, :sha256, integrity_key, data),
         true <-
           byte_size(mac) == byte_size(expected) and Plug.Crypto.secure_compare(mac, expected),
         decoded when is_map(decoded) <- :erlang.binary_to_term(data, [:safe]),
         true <- valid_data_shape?(decoded) do
      {:ok, decoded}
    else
      _invalid -> {:error, :identity_store_integrity_failed}
    end
  rescue
    _error -> {:error, :identity_store_integrity_failed}
  end

  defp valid_data_shape?(data) do
    is_map(data.accounts) and is_map(data.login_index) and is_map(data.authenticators) and
      is_map(data.verifiers) and is_map(data.sessions) and is_map(data.failures) and
      is_boolean(data.bootstrap_consumed)
  rescue
    _error -> false
  end

  defp persist(%Config{persistence?: false}, _data), do: :ok

  defp persist(%Config{} = config, data) do
    payload = :erlang.term_to_binary(data, [:deterministic])
    mac = :crypto.mac(:hmac, :sha256, config.integrity_key, payload)

    encoded =
      :erlang.term_to_binary(
        %{version: @snapshot_version, data: payload, mac: mac},
        [:deterministic]
      )

    temporary_path = config.path <> ".new"

    with :ok <- File.mkdir_p(Path.dirname(config.path)),
         :ok <- File.write(temporary_path, encoded, [:binary, :sync]),
         :ok <- File.chmod(temporary_path, 0o600),
         :ok <- File.rename(temporary_path, config.path) do
      :ok
    else
      {:error, _reason} = error -> error
    end
  end

  defp seed_bootstrap(%Config{bootstrap: nil}, data), do: {:ok, data}

  defp seed_bootstrap(%Config{} = config, %{bootstrap_consumed: false} = data) do
    bootstrap = config.bootstrap

    with {:ok, normalized} <- validate_account_attributes(bootstrap),
         credential when is_binary(credential) <- bootstrap[:credential],
         {:ok, verifier} <- Credential.build(credential, config.pbkdf2_iterations) do
      now = Map.get(bootstrap, :now, DateTime.utc_now())
      subject_ref = Map.get(bootstrap, :subject_ref, reference("human"))
      authenticator_ref = Map.get(bootstrap, :authenticator_ref, reference("authenticator"))

      account = %HumanAccount{
        subject_ref: subject_ref,
        display_name: normalized.display_name,
        login: normalized.login,
        status: :active,
        account_generation: 1,
        policy_revision: config.policy_revision,
        recovery_state: recovery_state(config),
        authenticator_refs: [authenticator_ref],
        inserted_at: now,
        updated_at: now
      }

      authenticator = %Authenticator{
        authenticator_ref: authenticator_ref,
        subject_ref: subject_ref,
        kind: :local_password,
        phishing_resistant: false,
        enrolled_at: now,
        verified_at: now,
        revoked_at: nil,
        status: :active,
        revision: 1
      }

      seeded =
        data
        |> put_in([:accounts, subject_ref], account)
        |> put_in([:login_index, normalized.login], subject_ref)
        |> put_in([:authenticators, authenticator_ref], authenticator)
        |> put_in([:verifiers, authenticator_ref], verifier)
        |> Map.put(:bootstrap_consumed, true)

      with :ok <- persist(config, seeded), do: {:ok, seeded}
    else
      _invalid -> {:error, :invalid_identity_bootstrap_config}
    end
  end

  defp seed_bootstrap(_config, data), do: {:ok, data}
end
