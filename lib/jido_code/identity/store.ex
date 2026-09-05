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
  alias JidoCode.Identity.HumanDelegation
  alias JidoCode.Identity.Membership
  alias JidoCode.Identity.RecoveryEvent
  alias JidoCode.Identity.Resource
  alias JidoCode.Identity.RevocationEvent
  alias JidoCode.Identity.Revocations

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

  @spec enroll_account(server(), map(), map(), String.t(), keyword()) ::
          {:ok, HumanAccount.t()} | {:error, atom()}
  def enroll_account(server \\ __MODULE__, context, attributes, credential, options \\ []) do
    GenServer.call(server, {:enroll_account, context, attributes, credential, options}, 30_000)
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

  @doc "Lists bounded same-account session summaries through one current session."
  @spec managed_sessions(server(), String.t(), keyword()) :: {:ok, [map()]} | {:error, atom()}
  def managed_sessions(server \\ __MODULE__, current_session_ref, options \\ []) do
    GenServer.call(server, {:managed_sessions, current_session_ref, options})
  end

  @doc "Revokes a same-account session by its non-bearer management reference."
  @spec revoke_managed_session(server(), String.t(), String.t(), keyword()) ::
          {:ok, :current | :other} | {:error, atom()}
  def revoke_managed_session(
        server \\ __MODULE__,
        current_session_ref,
        management_ref,
        options \\ []
      ) do
    GenServer.call(
      server,
      {:revoke_managed_session, current_session_ref, management_ref, options}
    )
  end

  @spec put_membership(server(), map(), map(), keyword()) ::
          {:ok, Membership.t()} | {:error, atom()}
  def put_membership(server \\ __MODULE__, context, attributes, options \\ []) do
    GenServer.call(server, {:put_membership, context, attributes, options})
  end

  @spec revoke_membership(server(), map(), String.t(), keyword()) ::
          {:ok, Membership.t()} | {:error, atom()}
  def revoke_membership(server \\ __MODULE__, context, membership_ref, options \\ []) do
    GenServer.call(server, {:revoke_membership, context, membership_ref, options})
  end

  @spec put_delegation(server(), map(), map(), keyword()) ::
          {:ok, HumanDelegation.t()} | {:error, atom()}
  def put_delegation(server \\ __MODULE__, context, attributes, options \\ []) do
    GenServer.call(server, {:put_delegation, context, attributes, options})
  end

  @spec revoke_delegation(server(), map(), String.t(), keyword()) ::
          {:ok, HumanDelegation.t()} | {:error, atom()}
  def revoke_delegation(server \\ __MODULE__, context, delegation_ref, options \\ []) do
    GenServer.call(server, {:revoke_delegation, context, delegation_ref, options})
  end

  @spec register_resource(server(), map(), map(), keyword()) ::
          {:ok, Resource.t()} | {:error, atom()}
  def register_resource(server \\ __MODULE__, context, attributes, options \\ []) do
    GenServer.call(server, {:register_resource, context, attributes, options})
  end

  @spec resolve_resource(server(), :factory | String.t()) ::
          {:ok, Resource.t()} | {:error, :not_found}
  def resolve_resource(server \\ __MODULE__, resource_ref) do
    GenServer.call(server, {:resolve_resource, resource_ref})
  end

  @doc "Returns a bounded registry candidate set; callers must authorize every item before use."
  @spec registered_resources(server(), atom(), pos_integer()) ::
          {:ok, [Resource.t()]} | {:error, :invalid_resource_query}
  def registered_resources(server \\ __MODULE__, kind, limit) do
    GenServer.call(server, {:registered_resources, kind, limit})
  end

  @spec authorization_snapshot(server(), String.t(), keyword()) ::
          {:ok, map()} | {:error, atom()}
  def authorization_snapshot(server \\ __MODULE__, subject_ref, options \\ []) do
    GenServer.call(server, {:authorization_snapshot, subject_ref, options})
  end

  @spec record_authorization(server(), map(), keyword()) :: :ok | {:error, atom()}
  def record_authorization(server \\ __MODULE__, attributes, options \\ []) do
    GenServer.call(server, {:record_authorization, attributes, options})
  end

  @spec publish_generation(server(), map(), keyword()) ::
          {:ok, RevocationEvent.t()} | {:error, atom()}
  def publish_generation(server \\ __MODULE__, attributes, options \\ []) do
    GenServer.call(server, {:publish_generation, attributes, options})
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

  def handle_call({:resolve_resource, resource_ref}, _from, state) do
    resolved_ref =
      if resource_ref == :factory, do: state.data.default_resource_ref, else: resource_ref

    {:reply, fetch(state.data.resources, resolved_ref), state}
  end

  def handle_call({:registered_resources, kind, limit}, _from, state)
      when kind in [:project] and is_integer(limit) and limit in 1..50 do
    resources =
      state.data.resources
      |> Map.values()
      |> Enum.filter(&(&1.kind == kind))
      |> Enum.sort_by(& &1.resource_ref)
      |> Enum.take(limit)

    {:reply, {:ok, resources}, state}
  end

  def handle_call({:registered_resources, _kind, _limit}, _from, state),
    do: {:reply, {:error, :invalid_resource_query}, state}

  def handle_call({:authorization_snapshot, subject_ref, options}, _from, state) do
    now = now(options)

    with :ok <- available(state),
         {:ok, account} <- fetch(state.data.accounts, subject_ref),
         :ok <- active_account(account) do
      memberships =
        state.data.memberships
        |> Map.values()
        |> Enum.filter(&current_membership?(&1, subject_ref, now))
        |> Enum.sort_by(& &1.membership_ref)

      delegations =
        state.data.delegations
        |> Map.values()
        |> Enum.filter(&current_delegation?(&1, subject_ref, state.config.policy_revision, now))
        |> Enum.sort_by(& &1.delegation_ref)

      snapshot = %{
        account: account,
        memberships: memberships,
        delegations: delegations,
        generations: state.data.generations,
        authority_adapter: state.config.authority_adapter,
        policy_revision: state.config.policy_revision
      }

      {:reply, {:ok, snapshot}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:put_membership, context, attributes, options}, _from, state) do
    with :ok <- available(state),
         :ok <- identity_admin_context(context),
         {:ok, membership} <- build_membership(state.data, attributes, now(options)),
         {:ok, _account} <- fetch(state.data.accounts, membership.subject_ref),
         prior = Map.get(state.data.memberships, membership.membership_ref),
         :ok <- immutable_membership_binding?(prior, membership) do
      next_membership = advance_membership(membership, prior)
      {next_data, events} = put_membership_transition(state, prior, next_membership, now(options))
      commit(state, next_data, {:ok, next_membership}, events)
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:revoke_membership, context, membership_ref, options}, _from, state) do
    with :ok <- available(state),
         :ok <- identity_admin_context(context),
         {:ok, membership} <- fetch(state.data.memberships, membership_ref),
         true <- membership.status == :active do
      now = now(options)
      next_membership = %{membership | status: :revoked, revision: membership.revision + 1}
      {next_data, events} = put_membership_transition(state, membership, next_membership, now)
      commit(state, next_data, {:ok, next_membership}, events)
    else
      false -> {:reply, {:error, :membership_inactive}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:put_delegation, context, attributes, options}, _from, state) do
    trusted_attributes =
      if is_map(attributes),
        do: Map.put(attributes, :policy_revision, state.config.policy_revision),
        else: attributes

    with :ok <- available(state),
         :ok <- identity_admin_context(context),
         {:ok, delegation} <- build_delegation(state.data, trusted_attributes, now(options)),
         :ok <- delegation_attenuated?(state.data, delegation),
         prior = Map.get(state.data.delegations, delegation.delegation_ref),
         :ok <- immutable_delegation_binding?(prior, delegation) do
      revision = if prior, do: prior.delegation_revision + 1, else: 1
      next_delegation = %{delegation | delegation_revision: revision}
      prior_generation = state.data.generations.delegation
      next_generations = Map.put(state.data.generations, :delegation, prior_generation + 1)

      next_data =
        state.data
        |> put_in([:delegations, delegation.delegation_ref], next_delegation)
        |> Map.put(:generations, next_generations)

      event =
        revocation_event(
          :delegation,
          delegation.delegate_subject_ref,
          nil,
          prior_generation,
          prior_generation + 1,
          state.config.policy_revision,
          now(options)
        )

      commit(state, next_data, {:ok, next_delegation}, [event])
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:revoke_delegation, context, delegation_ref, options}, _from, state) do
    with :ok <- available(state),
         :ok <- identity_admin_context(context),
         {:ok, delegation} <- fetch(state.data.delegations, delegation_ref),
         true <- delegation.status == :active do
      now = now(options)
      prior_generation = state.data.generations.delegation

      next_delegation = %{
        delegation
        | status: :revoked,
          delegation_revision: delegation.delegation_revision + 1,
          revocation_generation: delegation.revocation_generation + 1
      }

      next_data =
        state.data
        |> put_in([:delegations, delegation_ref], next_delegation)
        |> put_in([:generations, :delegation], prior_generation + 1)

      event =
        revocation_event(
          :delegation,
          delegation.delegate_subject_ref,
          nil,
          prior_generation,
          prior_generation + 1,
          state.config.policy_revision,
          now
        )

      commit(state, next_data, {:ok, next_delegation}, [event])
    else
      false -> {:reply, {:error, :delegation_inactive}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:register_resource, context, attributes, options}, _from, state) do
    with :ok <- available(state),
         :ok <- identity_admin_context(context),
         {:ok, resource} <- build_resource(state.data, attributes),
         :ok <- resource_parent_valid?(state.data, resource),
         prior = Map.get(state.data.resources, resource.resource_ref),
         :ok <- immutable_resource_binding?(prior, resource) do
      revision = if prior, do: prior.registry_revision + 1, else: 1
      next_resource = %{resource | registry_revision: revision}
      dimension = if resource.project_ref, do: :project, else: :tenant
      prior_generation = Map.fetch!(state.data.generations, dimension)

      next_data =
        state.data
        |> put_in([:resources, resource.resource_ref], next_resource)
        |> put_in([:generations, dimension], prior_generation + 1)

      event =
        revocation_event(
          dimension,
          nil,
          resource.resource_ref,
          prior_generation,
          prior_generation + 1,
          state.config.policy_revision,
          now(options)
        )

      commit(state, next_data, {:ok, next_resource}, [event])
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:record_authorization, attributes, options}, _from, state) do
    with :ok <- available(state),
         :ok <- current_authorization_expectation(state, attributes, now(options)),
         {:ok, audit} <-
           authorization_audit(attributes, state.config.policy_revision, now(options)) do
      next_data = append_audit(state.data, audit)
      commit(state, next_data, :ok)
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:publish_generation, attributes, options}, _from, state)
      when is_map(attributes) do
    with :ok <- available(state),
         :ok <- identity_admin_context(attributes[:context]),
         dimension when dimension in [:graph, :incident] <- attributes[:dimension],
         current <- Map.fetch!(state.data.generations, dimension),
         expected when expected == current <- attributes[:prior_generation],
         next when next == current + 1 <- attributes[:next_generation] do
      event =
        revocation_event(
          dimension,
          attributes[:subject_ref],
          attributes[:resource_ref],
          current,
          next,
          state.config.policy_revision,
          now(options)
        )

      next_data = put_in(state.data, [:generations, dimension], next)
      commit(state, next_data, {:ok, event}, [event])
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
      _invalid -> {:reply, {:error, :invalid_generation_transition}, state}
    end
  end

  def handle_call({:publish_generation, _attributes, _options}, _from, state),
    do: {:reply, {:error, :invalid_generation_transition}, state}

  def handle_call({:issue_session, authentication, options}, _from, state) do
    with :ok <- available(state),
         {:ok, account} <- authenticated_account(state.data, authentication),
         {:ok, authenticated_at} <- fetch_datetime(authentication, :authenticated_at),
         {:ok, assurance} <- fetch_assurance(authentication),
         :ok <- authentication_assurance(state.data, account, authentication, assurance),
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

      event =
        revocation_event(
          :session,
          session.subject_ref,
          session_ref,
          session.session_generation,
          session.session_generation + 1,
          session.policy_revision,
          now
        )

      commit(state, next_data, :ok, [event])
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:managed_sessions, current_session_ref, options}, _from, state) do
    now = now(options)

    with :ok <- available(state),
         {:ok, current} <- fetch(state.data.sessions, current_session_ref),
         {:ok, account} <- fetch(state.data.accounts, current.subject_ref),
         :ok <- current_session(current, account, now, state.config) do
      sessions =
        state.data.sessions
        |> Map.values()
        |> Enum.filter(fn session ->
          session.subject_ref == current.subject_ref and
            current_session(session, account, now, state.config) == :ok
        end)
        |> Enum.sort_by(&DateTime.to_unix(&1.last_seen_at), :desc)
        |> Enum.take(20)
        |> Enum.map(&managed_session_summary(&1, current_session_ref))

      {:reply, {:ok, sessions}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call(
        {:revoke_managed_session, current_session_ref, management_ref, options},
        _from,
        state
      ) do
    now = now(options)

    with :ok <- available(state),
         true <- is_binary(management_ref) and byte_size(management_ref) in 1..64,
         {:ok, current} <- fetch(state.data.sessions, current_session_ref),
         {:ok, account} <- fetch(state.data.accounts, current.subject_ref),
         :ok <- current_session(current, account, now, state.config),
         {:ok, target} <- managed_session_target(state.data.sessions, current, management_ref),
         :ok <- current_session(target, account, now, state.config) do
      next_session = revoke(target, now)

      next_data =
        state.data
        |> put_in([:sessions, target.session_ref], next_session)
        |> append_audit(
          audit_event(
            current.subject_ref,
            "identity.session.revoke",
            target.session_ref,
            :committed,
            target.policy_revision,
            reference("identity_receipt"),
            now
          )
        )

      emit_session_telemetry(:revoked, next_session, :revoked)

      event =
        revocation_event(
          :session,
          target.subject_ref,
          target.session_ref,
          target.session_generation,
          target.session_generation + 1,
          target.policy_revision,
          now
        )

      outcome = if(target.session_ref == current_session_ref, do: :current, else: :other)
      commit(state, next_data, {:ok, outcome}, [event])
    else
      false -> {:reply, {:error, :invalid_session_management_ref}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:bootstrap, attributes, credential, options}, _from, state) do
    with :ok <- available(state),
         :ok <- local_bootstrap(options),
         :ok <- bootstrap_available(state.data),
         {:ok, normalized} <- validate_account_attributes(attributes),
         :ok <- validate_bootstrap_authority(attributes),
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
        |> add_bootstrap_authority(account, attributes, now)
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

  def handle_call({:enroll_account, context, attributes, credential, options}, _from, state) do
    with :ok <- available(state),
         :ok <- identity_admin_context(context),
         {:ok, normalized} <- validate_account_attributes(attributes),
         false <- Map.has_key?(state.data.login_index, normalized.login),
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

      next_data =
        state.data
        |> put_in([:accounts, subject_ref], account)
        |> put_in([:login_index, normalized.login], subject_ref)
        |> put_in([:authenticators, authenticator_ref], authenticator)
        |> put_in([:verifiers, authenticator_ref], verifier)
        |> append_audit(
          audit_event(
            context.actor_ref,
            "identity.account.enroll",
            subject_ref,
            :committed,
            state.config.policy_revision,
            reference("identity_receipt"),
            now
          )
        )

      commit(state, next_data, {:ok, account})
    else
      true -> {:reply, {:error, :login_already_enrolled}, state}
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

      event = account_revocation_event(account, next_account, now)
      commit(state, next_data, {:ok, next_account}, [event])
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

      event = account_revocation_event(account, next_account, now)
      commit(state, next_data, {:ok, next_account}, [event])
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

      event = account_revocation_event(account, next_account, now)
      commit(state, next_data, {:ok, next_account}, [event])
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

      event = account_revocation_event(account, next_account, now)
      commit(state, next_data, {:ok, next_account}, [event])
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

  defp commit(state, next_data, reply, revocations \\ []) do
    case persist(state.config, next_data) do
      :ok ->
        Enum.each(revocations, &Revocations.publish/1)
        {:reply, reply, %{state | data: next_data}}

      {:error, _reason} ->
        {:reply, {:error, :identity_store_unavailable}, state}
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

  defp validate_bootstrap_authority(attributes) when is_map(attributes) do
    tenant_ref = Map.get(attributes, :tenant_ref, "tenant_default")
    roles = Map.get(attributes, :roles, [:factory_administrator])
    route_groups = Map.get(attributes, :route_groups, [:administration])

    with true <- valid_ref?(tenant_ref),
         true <- exact_atoms?(roles, JidoCode.Identity.RoutePolicy.roles()),
         true <- exact_atoms?(route_groups, JidoCode.Identity.RoutePolicy.areas()),
         true <- valid_optional_ref?(attributes[:factory_resource_ref]),
         true <- valid_optional_ref?(attributes[:membership_ref]) do
      :ok
    else
      _invalid -> {:error, :invalid_bootstrap_authority}
    end
  end

  defp validate_bootstrap_authority(_attributes), do: {:error, :invalid_bootstrap_authority}

  defp valid_optional_ref?(nil), do: true
  defp valid_optional_ref?(value), do: valid_ref?(value)

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

  defp build_membership(data, attributes, now) when is_map(attributes) do
    membership_ref = Map.get(attributes, :membership_ref, reference("membership"))
    subject_ref = attributes[:subject_ref]
    tenant_ref = attributes[:tenant_ref]
    project_ref = attributes[:project_ref]
    roles = attributes[:roles]
    route_groups = attributes[:route_groups]
    clearance = Map.get(attributes, :clearance, :internal)
    valid_from = Map.get(attributes, :valid_from, now)
    valid_to = Map.get(attributes, :valid_to, ~U[9999-12-31 23:59:59Z])

    with true <- valid_ref?(membership_ref),
         true <- valid_ref?(subject_ref),
         true <- valid_ref?(tenant_ref),
         true <- is_nil(project_ref) or valid_ref?(project_ref),
         true <- exact_atoms?(roles, JidoCode.Identity.RoutePolicy.roles()),
         true <- exact_atoms?(route_groups, JidoCode.Identity.RoutePolicy.areas()),
         true <- clearance in [:public, :internal, :confidential, :secret_reference],
         true <- match?(%DateTime{}, valid_from) and match?(%DateTime{}, valid_to),
         true <- DateTime.compare(valid_from, valid_to) == :lt,
         true <- membership_scope_known?(data, tenant_ref, project_ref) do
      {:ok,
       %Membership{
         membership_ref: membership_ref,
         subject_ref: subject_ref,
         tenant_ref: tenant_ref,
         project_ref: project_ref,
         roles: Enum.uniq(roles),
         route_groups: Enum.uniq(route_groups),
         clearance: clearance,
         valid_from: valid_from,
         valid_to: valid_to,
         revision: 1,
         status: :active
       }}
    else
      _invalid -> {:error, :invalid_membership}
    end
  end

  defp build_membership(_data, _attributes, _now), do: {:error, :invalid_membership}

  defp advance_membership(membership, nil), do: membership

  defp advance_membership(membership, prior) do
    %{membership | revision: prior.revision + 1}
  end

  defp put_membership_transition(state, prior, membership, now) do
    dimensions =
      [:role, :tenant] ++
        if membership.project_ref || (prior && prior.project_ref), do: [:project], else: []

    {generations, events} =
      Enum.reduce(dimensions, {state.data.generations, []}, fn dimension, {generations, events} ->
        prior_generation = Map.fetch!(generations, dimension)
        next_generation = prior_generation + 1

        event =
          revocation_event(
            dimension,
            membership.subject_ref,
            membership.project_ref || membership.tenant_ref,
            prior_generation,
            next_generation,
            state.config.policy_revision,
            now
          )

        {Map.put(generations, dimension, next_generation), [event | events]}
      end)

    data =
      state.data
      |> put_in([:memberships, membership.membership_ref], membership)
      |> Map.put(:generations, generations)

    {data, Enum.reverse(events)}
  end

  defp build_delegation(data, attributes, now) when is_map(attributes) do
    delegation_ref = Map.get(attributes, :delegation_ref, reference("human_delegation"))
    issuer = attributes[:issuer_subject_ref]
    delegate = attributes[:delegate_subject_ref]
    resource_refs = attributes[:resource_refs]
    actions = attributes[:actions]
    graph_families = attributes[:graph_families]
    environment = attributes[:environment]
    valid_from = Map.get(attributes, :valid_from, now)
    valid_to = attributes[:valid_to]
    parent_ref = attributes[:attenuation_parent_ref]
    minimum_assurance = Map.get(attributes, :minimum_assurance, :baseline)
    maximum_classification = Map.get(attributes, :maximum_classification, :internal)
    obligations = Map.get(attributes, :obligations, [])

    with true <- valid_ref?(delegation_ref),
         true <- valid_ref?(issuer) and valid_ref?(delegate) and issuer != delegate,
         {:ok, _issuer} <- fetch(data.accounts, issuer),
         {:ok, _delegate} <- fetch(data.accounts, delegate),
         true <- bounded_refs?(resource_refs, data.resources),
         true <- exact_atoms?(actions, JidoCode.Identity.RoutePolicy.actions()),
         true <- is_list(graph_families) and graph_families != [] and length(graph_families) <= 32,
         true <- Enum.all?(graph_families, &is_atom/1),
         true <- environment in [:development, :test, :production],
         true <- match?(%DateTime{}, valid_from) and match?(%DateTime{}, valid_to),
         true <- DateTime.compare(valid_from, valid_to) == :lt,
         true <- is_nil(parent_ref) or valid_ref?(parent_ref),
         true <- minimum_assurance in @allowed_assurance,
         true <- maximum_classification in [:public, :internal, :confidential, :secret_reference],
         true <- is_list(obligations) and Enum.all?(obligations, &is_atom/1) do
      {:ok,
       %HumanDelegation{
         delegation_ref: delegation_ref,
         issuer_subject_ref: issuer,
         delegate_subject_ref: delegate,
         resource_refs: Enum.uniq(resource_refs),
         actions: Enum.uniq(actions),
         graph_families: Enum.uniq(graph_families),
         environment: environment,
         valid_from: valid_from,
         valid_to: valid_to,
         policy_revision: attributes[:policy_revision] || "invalid",
         delegation_revision: 1,
         attenuation_parent_ref: parent_ref,
         revocation_generation: 1,
         minimum_assurance: minimum_assurance,
         maximum_classification: maximum_classification,
         obligations: Enum.uniq(obligations),
         status: :active
       }}
    else
      _invalid -> {:error, :invalid_delegation}
    end
  end

  defp build_delegation(_data, _attributes, _now), do: {:error, :invalid_delegation}

  defp delegation_attenuated?(_data, %HumanDelegation{attenuation_parent_ref: nil}), do: :ok

  defp delegation_attenuated?(data, delegation) do
    with {:ok, parent} <- fetch(data.delegations, delegation.attenuation_parent_ref),
         true <- parent.status == :active,
         true <- delegation.issuer_subject_ref == parent.delegate_subject_ref,
         true <- subset?(delegation.resource_refs, parent.resource_refs),
         true <- subset?(delegation.actions, parent.actions),
         true <- subset?(delegation.graph_families, parent.graph_families),
         true <- delegation.environment == parent.environment,
         true <- DateTime.compare(delegation.valid_from, parent.valid_from) in [:eq, :gt],
         true <- DateTime.compare(delegation.valid_to, parent.valid_to) in [:eq, :lt],
         true <-
           assurance_rank(delegation.minimum_assurance) >=
             assurance_rank(parent.minimum_assurance),
         true <-
           classification_rank(delegation.maximum_classification) <=
             classification_rank(parent.maximum_classification),
         true <- subset?(parent.obligations, delegation.obligations) do
      :ok
    else
      _widened -> {:error, :delegation_widened}
    end
  end

  defp build_resource(data, attributes) when is_map(attributes) do
    resource_ref = Map.get(attributes, :resource_ref, reference("resource"))
    kind = attributes[:kind]
    iri = attributes[:iri]
    tenant_ref = attributes[:tenant_ref]
    project_ref = attributes[:project_ref]
    parent_ref = attributes[:parent_ref]
    graph_scope_iri = attributes[:graph_scope_iri]
    classification = Map.get(attributes, :classification, :internal)
    environment = Map.get(attributes, :environment, :production)
    lifecycle = Map.get(attributes, :lifecycle, :active)

    with true <- valid_ref?(resource_ref),
         true <-
           kind in [
             :factory,
             :project,
             :attempt,
             :interaction_session,
             :candidate,
             :wiki_preview,
             :graph
           ],
         true <- valid_iri?(iri) and valid_iri?(graph_scope_iri),
         true <- valid_ref?(tenant_ref),
         true <- is_nil(project_ref) or valid_ref?(project_ref),
         true <- is_nil(parent_ref) or Map.has_key?(data.resources, parent_ref),
         true <-
           classification in [
             :public,
             :internal,
             :confidential,
             :secret_reference,
             :audit,
             :personal
           ],
         true <- environment in [:development, :test, :production],
         true <- lifecycle in [:active, :read_only, :archived] do
      {:ok,
       %Resource{
         resource_ref: resource_ref,
         kind: kind,
         iri: iri,
         tenant_ref: tenant_ref,
         project_ref: project_ref,
         parent_ref: parent_ref,
         graph_scope_iri: graph_scope_iri,
         classification: classification,
         environment: environment,
         lifecycle: lifecycle,
         registry_revision: 1
       }}
    else
      _invalid -> {:error, :invalid_resource}
    end
  end

  defp build_resource(_data, _attributes), do: {:error, :invalid_resource}

  defp resource_parent_valid?(_data, %Resource{kind: :factory, parent_ref: nil, project_ref: nil}),
       do: :ok

  defp resource_parent_valid?(data, %Resource{parent_ref: parent_ref} = resource)
       when is_binary(parent_ref) do
    case Map.get(data.resources, parent_ref) do
      %Resource{} = parent ->
        if parent.tenant_ref == resource.tenant_ref and
             (is_nil(parent.project_ref) or parent.project_ref == resource.project_ref),
           do: :ok,
           else: {:error, :resource_scope_mismatch}

      _missing ->
        {:error, :resource_parent_missing}
    end
  end

  defp resource_parent_valid?(_data, _resource), do: {:error, :resource_parent_missing}

  defp authorization_audit(attributes, policy_revision, now) when is_map(attributes) do
    with actor_ref when is_binary(actor_ref) <- attributes[:actor_ref],
         operation when is_atom(operation) <- attributes[:operation],
         outcome
         when outcome in [
                :allowed,
                :concealed_not_found,
                :redacted,
                :denied,
                :unavailable,
                :revoked,
                :step_up_required
              ] <-
           attributes[:outcome],
         correlation_ref when is_binary(correlation_ref) <- attributes[:correlation_ref] do
      object_ref =
        if outcome == :concealed_not_found,
          do: "concealed_resource",
          else: attributes[:resource_ref] || "unknown_resource"

      {:ok,
       audit_event(
         actor_ref,
         "identity.authorization.#{operation}",
         object_ref,
         outcome,
         policy_revision,
         correlation_ref,
         now
       )}
    else
      _invalid -> {:error, :invalid_authorization_audit}
    end
  end

  defp authorization_audit(_attributes, _policy_revision, _now),
    do: {:error, :invalid_authorization_audit}

  defp current_authorization_expectation(state, attributes, now) when is_map(attributes) do
    with session_ref when is_binary(session_ref) <- attributes[:session_ref],
         {:ok, session} <- fetch(state.data.sessions, session_ref),
         {:ok, account} <- fetch(state.data.accounts, session.subject_ref),
         :ok <- current_session(session, account, now, state.config),
         true <- attributes[:actor_ref] == account.subject_ref,
         true <- attributes[:session_generation] == session.session_generation,
         true <- attributes[:account_generation] == account.account_generation,
         true <- attributes[:policy_revision] == state.config.policy_revision,
         true <- attributes[:revocation_generations] == state.data.generations,
         {:ok, resource} <- fetch(state.data.resources, attributes[:resource_ref]),
         true <- attributes[:resource_revision] == resource.registry_revision do
      :ok
    else
      _stale -> {:error, :authorization_stale}
    end
  end

  defp current_authorization_expectation(_state, _attributes, _now),
    do: {:error, :authorization_stale}

  defp current_membership?(membership, subject_ref, now) do
    membership.subject_ref == subject_ref and membership.status == :active and
      DateTime.compare(membership.valid_from, now) in [:lt, :eq] and
      DateTime.compare(now, membership.valid_to) == :lt
  end

  defp current_delegation?(delegation, subject_ref, policy_revision, now) do
    delegation.delegate_subject_ref == subject_ref and delegation.status == :active and
      delegation.policy_revision == policy_revision and
      DateTime.compare(delegation.valid_from, now) in [:lt, :eq] and
      DateTime.compare(now, delegation.valid_to) == :lt
  end

  defp immutable_membership_binding?(nil, _membership), do: :ok

  defp immutable_membership_binding?(prior, membership) do
    if {prior.subject_ref, prior.tenant_ref, prior.project_ref} ==
         {membership.subject_ref, membership.tenant_ref, membership.project_ref},
       do: :ok,
       else: {:error, :membership_binding_immutable}
  end

  defp immutable_delegation_binding?(nil, _delegation), do: :ok

  defp immutable_delegation_binding?(prior, delegation) do
    if {prior.issuer_subject_ref, prior.delegate_subject_ref} ==
         {delegation.issuer_subject_ref, delegation.delegate_subject_ref},
       do: :ok,
       else: {:error, :delegation_binding_immutable}
  end

  defp immutable_resource_binding?(nil, _resource), do: :ok

  defp immutable_resource_binding?(prior, resource) do
    if {prior.kind, prior.tenant_ref, prior.project_ref, prior.parent_ref} ==
         {resource.kind, resource.tenant_ref, resource.project_ref, resource.parent_ref},
       do: :ok,
       else: {:error, :resource_binding_immutable}
  end

  defp membership_scope_known?(data, tenant_ref, nil) do
    Enum.any?(data.resources, fn {_ref, resource} ->
      resource.tenant_ref == tenant_ref and resource.kind == :factory
    end)
  end

  defp membership_scope_known?(data, tenant_ref, project_ref) do
    Enum.any?(data.resources, fn {_ref, resource} ->
      resource.tenant_ref == tenant_ref and resource.project_ref == project_ref
    end)
  end

  defp bounded_refs?(refs, resources) do
    is_list(refs) and refs != [] and length(refs) <= 100 and
      Enum.all?(refs, &Map.has_key?(resources, &1))
  end

  defp exact_atoms?(values, allowed) do
    is_list(values) and values != [] and length(values) <= length(allowed) and
      Enum.all?(values, &(&1 in allowed))
  end

  defp valid_ref?(value),
    do:
      is_binary(value) and byte_size(value) in 3..256 and
        Regex.match?(~r/^[A-Za-z0-9][A-Za-z0-9_.:@+-]*$/, value)

  defp valid_iri?(value) when is_binary(value) do
    uri = URI.parse(value)
    uri.scheme in ["http", "https", "urn"] and is_nil(uri.userinfo) and is_nil(uri.fragment)
  end

  defp valid_iri?(_value), do: false

  defp subset?(left, right), do: MapSet.subset?(MapSet.new(left), MapSet.new(right))

  defp assurance_rank(:baseline), do: 1
  defp assurance_rank(:phishing_resistant), do: 2
  defp assurance_rank(:action_bound_step_up), do: 3

  defp classification_rank(:public), do: 1
  defp classification_rank(:internal), do: 2
  defp classification_rank(:confidential), do: 3
  defp classification_rank(:secret_reference), do: 4

  defp revocation_event(
         dimension,
         subject_ref,
         resource_ref,
         prior_generation,
         next_generation,
         policy_revision,
         now
       ) do
    %RevocationEvent{
      event_ref: reference("revocation_event"),
      dimension: dimension,
      subject_ref: subject_ref,
      resource_ref: resource_ref,
      prior_generation: prior_generation,
      next_generation: next_generation,
      policy_revision: policy_revision,
      occurred_at: now
    }
  end

  defp account_revocation_event(account, next_account, now) do
    revocation_event(
      :account,
      account.subject_ref,
      nil,
      account.account_generation,
      next_account.account_generation,
      next_account.policy_revision,
      now
    )
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

  defp authentication_assurance(data, account, authentication, assurance) do
    with {:ok, authenticator, _verifier} <- active_authenticator(data, account),
         true <- authentication[:authenticator_ref] == authenticator.authenticator_ref,
         :ok <- assurance_available(authenticator, assurance) do
      :ok
    else
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
      memberships: %{},
      delegations: %{},
      resources: %{},
      default_resource_ref: nil,
      generations: %{
        role: 1,
        delegation: 1,
        project: 1,
        tenant: 1,
        graph: 1,
        incident: 1
      },
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
      is_map(data.verifiers) and is_map(data.sessions) and is_map(data.memberships) and
      is_map(data.delegations) and is_map(data.resources) and is_map(data.generations) and
      is_map(data.failures) and is_boolean(data.bootstrap_consumed)
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
         :ok <- validate_bootstrap_authority(bootstrap),
         credential when is_binary(credential) <- bootstrap[:credential],
         {:ok, verifier} <- Credential.build(credential, config.pbkdf2_iterations),
         now = Map.get(bootstrap, :now, DateTime.utc_now()),
         true <- match?(%DateTime{}, now),
         subject_ref = Map.get(bootstrap, :subject_ref, reference("human")),
         true <- valid_ref?(subject_ref),
         authenticator_ref = Map.get(bootstrap, :authenticator_ref, reference("authenticator")),
         true <- valid_ref?(authenticator_ref) do
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
        |> add_bootstrap_authority(account, bootstrap, now)

      with :ok <- persist(config, seeded), do: {:ok, seeded}
    else
      _invalid -> {:error, :invalid_identity_bootstrap_config}
    end
  end

  defp seed_bootstrap(_config, data), do: {:ok, data}

  defp add_bootstrap_authority(data, account, attributes, now) do
    surface = Application.fetch_env!(:jido_code, :product_surface)
    resource_ref = Map.get(attributes, :factory_resource_ref, reference("resource_factory"))
    tenant_ref = Map.get(attributes, :tenant_ref, "tenant_default")
    roles = Map.get(attributes, :roles, [:factory_administrator])
    route_groups = Map.get(attributes, :route_groups, [:administration])

    resource = %Resource{
      resource_ref: resource_ref,
      kind: :factory,
      iri: Keyword.fetch!(surface, :factory_iri),
      tenant_ref: tenant_ref,
      project_ref: nil,
      parent_ref: nil,
      graph_scope_iri: Keyword.fetch!(surface, :factory_scope_iri),
      classification: :internal,
      environment: runtime_environment(),
      lifecycle: :active,
      registry_revision: 1
    }

    membership = %Membership{
      membership_ref: Map.get(attributes, :membership_ref, reference("membership")),
      subject_ref: account.subject_ref,
      tenant_ref: tenant_ref,
      project_ref: nil,
      roles: Enum.uniq(roles),
      route_groups: Enum.uniq(route_groups),
      clearance: :internal,
      valid_from: now,
      valid_to: ~U[9999-12-31 23:59:59Z],
      revision: 1,
      status: :active
    }

    data
    |> put_in([:resources, resource_ref], resource)
    |> put_in([:memberships, membership.membership_ref], membership)
    |> Map.put(:default_resource_ref, resource_ref)
  end

  defp runtime_environment do
    case Application.get_env(:jido_code, :runtime_mode, :production) do
      value when value in [:dev, :development] -> :development
      :test -> :test
      _other -> :production
    end
  end

  defp managed_session_summary(session, current_session_ref) do
    %{
      management_ref: session_management_ref(session.session_ref),
      current: session.session_ref == current_session_ref,
      issued_at: session.issued_at,
      last_seen_at: session.last_seen_at,
      hard_expires_at: session.hard_expires_at,
      idle_expires_at: session.idle_expires_at,
      assurance: session.assurance
    }
  end

  defp managed_session_target(sessions, current, management_ref) do
    sessions
    |> Map.values()
    |> Enum.find(fn session ->
      session.subject_ref == current.subject_ref and
        secure_equal?(session_management_ref(session.session_ref), management_ref)
    end)
    |> case do
      %BrowserSession{} = session -> {:ok, session}
      nil -> {:error, :not_found}
    end
  end

  defp session_management_ref(session_ref) do
    :sha256
    |> :crypto.hash("jido-code-session-management\0" <> session_ref)
    |> Base.url_encode64(padding: false)
  end

  defp secure_equal?(left, right)
       when is_binary(left) and is_binary(right) and byte_size(left) == byte_size(right),
       do: Plug.Crypto.secure_compare(left, right)

  defp secure_equal?(_left, _right), do: false
end
