defmodule JidoCode.Knowledge.ProjectionSubscription do
  @moduledoc """
  Revision-aware projection refresh process over disposable change hints.

  Notifications are coalesced only to wake a fresh authorized query. Reconnect,
  mailbox loss, authority changes, and process restart all converge by querying
  from the consumer's last evaluated dataset revision.
  """

  use GenServer

  alias JidoCode.Knowledge.AuthorizationScope
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.ChangeEvent
  alias JidoCode.Knowledge.ChangeFeed
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ProjectionEnvelope
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @default_debounce 10

  @doc "A pull-credit subscription: only its HTTP owner can request or acknowledge work."
  def start_page_stream(options), do: GenServer.start(__MODULE__, {:page_stream, options})
  def poll(server), do: GenServer.call(server, :poll, 1_000)
  def evaluated(server, revision), do: GenServer.call(server, {:evaluated, revision}, 1_000)

  def page_limits, do: %{scopes: 2, families: 20, mailbox: 64, refresh_ms: 5_000}

  def start_link(options) do
    case Keyword.get(options, :name) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec last_revision(GenServer.server()) :: non_neg_integer()
  def last_revision(server), do: GenServer.call(server, :last_revision)

  @spec reconnect(GenServer.server(), non_neg_integer()) :: :ok
  def reconnect(server, current_revision),
    do: GenServer.cast(server, {:reconnect, current_revision})

  @spec reauthorize(GenServer.server(), AuthorityContext.t()) :: :ok
  def reauthorize(server, %AuthorityContext{} = authority),
    do: GenServer.cast(server, {:reauthorize, authority})

  @impl true
  def init({:page_stream, options}) do
    scopes = Keyword.fetch!(options, :scopes)
    families = Keyword.fetch!(options, :families)
    owner = Keyword.fetch!(options, :owner)
    revision = Keyword.fetch!(options, :last_revision)

    with true <- is_pid(owner) and is_list(scopes) and length(scopes) in 1..2,
         true <-
           Enum.all?(
             scopes,
             &(ResourceIdentity.validate(&1) == :ok and
                 (subscription_scope?(&1) or String.contains?(&1, "/repo/")))
           ),
         true <- is_list(families) and length(families) in 1..20,
         true <- Enum.all?(families, &(&1 in JidoCode.Knowledge.GraphRegistry.families())),
         true <- is_integer(revision) and revision >= 0,
         true <- Enum.all?(scopes, &(ChangeFeed.subscribe(&1) == :ok)) do
      {:ok,
       %{
         mode: :page_stream,
         owner: owner,
         monitor: Process.monitor(owner),
         scopes: scopes,
         families: families,
         last_revision: revision,
         hinted_revision: revision,
         pending: false,
         next_refresh: monotonic() + 5_000
       }}
    else
      _ -> {:stop, :invalid_page_subscription}
    end
  end

  def init(options) do
    scope_iri = Keyword.fetch!(options, :scope_iri)
    authority = Keyword.fetch!(options, :authority)
    refresh = Keyword.fetch!(options, :refresh)
    last_revision = Keyword.get(options, :last_revision, 0)

    with :ok <- ResourceIdentity.validate(scope_iri),
         true <- subscription_scope?(scope_iri),
         true <- match?(%AuthorityContext{}, authority),
         true <- is_function(refresh, 2),
         true <- is_integer(last_revision) and last_revision >= 0,
         {:ok, digest} <- AuthorizationScope.digest(authority, scope_iri),
         :ok <- ChangeFeed.subscribe(scope_iri, Keyword.get(options, :pubsub, JidoCode.PubSub)) do
      {:ok,
       %{
         scope_iri: scope_iri,
         authority: authority,
         authority_digest: digest,
         refresh: refresh,
         owner: Keyword.get(options, :owner, self()),
         last_revision: last_revision,
         hinted_revision: last_revision,
         refresh_scheduled?: false,
         debounce_ms: Keyword.get(options, :debounce_ms, @default_debounce)
       }}
    else
      {:error, %Error{} = error} -> {:stop, error}
      _invalid -> {:stop, Error.new(:invalid_input, :projection_subscription)}
    end
  end

  @impl true
  def handle_call(:poll, {owner, _}, %{mode: :page_stream, owner: owner} = state) do
    due = state.hinted_revision > state.last_revision or monotonic() >= state.next_refresh

    if due and not state.pending do
      reason = if state.hinted_revision > state.last_revision, do: :hint, else: :reconcile
      {:reply, {:refresh, reason}, %{state | pending: true}}
    else
      {:reply, :idle, state}
    end
  end

  def handle_call(
        {:evaluated, revision},
        {owner, _},
        %{mode: :page_stream, owner: owner, pending: true} = state
      )
      when is_integer(revision) and revision >= 0 do
    if revision >= state.last_revision do
      {:reply, :ok,
       %{state | last_revision: revision, pending: false, next_refresh: monotonic() + 5_000}}
    else
      {:reply, {:error, :stale_revision},
       %{state | pending: false, next_refresh: monotonic() + 5_000}}
    end
  end

  def handle_call(_request, _from, %{mode: :page_stream} = state),
    do: {:reply, {:error, :invalid_subscription_request}, state}

  def handle_call(:last_revision, _from, state), do: {:reply, state.last_revision, state}

  @impl true
  def handle_cast(_message, %{mode: :page_stream} = state), do: {:noreply, state}

  def handle_cast({:reconnect, current_revision}, state)
      when is_integer(current_revision) and current_revision >= 0 do
    {:noreply, hint_refresh(state, current_revision)}
  end

  def handle_cast({:reauthorize, authority}, state) do
    case AuthorizationScope.digest(authority, state.scope_iri) do
      {:ok, digest} when digest == state.authority_digest ->
        {:noreply, %{state | authority: authority}}

      {:ok, digest} ->
        next = %{state | authority: authority, authority_digest: digest}
        {:noreply, hint_refresh(next, max(next.hinted_revision, next.last_revision + 1))}

      {:error, %Error{} = error} ->
        send(state.owner, {:projection_inaccessible, error})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        {:DOWN, monitor, :process, owner, _},
        %{mode: :page_stream, monitor: monitor, owner: owner} = state
      ),
      do: {:stop, :normal, state}

  def handle_info({:jido_code_change, %ChangeEvent{} = event}, %{mode: :page_stream} = state) do
    {:message_queue_len, count} = Process.info(self(), :message_queue_len)

    cond do
      count > 64 ->
        {:stop, :subscription_overflow, state}

      event.scope_iri in state.scopes and is_integer(event.dataset_revision) and
        event.dataset_revision in 1..9_223_372_036_854_775_807 and
        is_list(event.affected_graphs) and length(event.affected_graphs) <= 20 and
          Enum.any?(event.affected_graphs, fn
            %{family: family} -> family in state.families
            _ -> false
          end) ->
        {:noreply, %{state | hinted_revision: max(state.hinted_revision, event.dataset_revision)}}

      true ->
        {:noreply, state}
    end
  end

  def handle_info(_message, %{mode: :page_stream} = state), do: {:noreply, state}

  def handle_info({:jido_code_change, %ChangeEvent{scope_iri: scope} = event}, state)
      when scope == state.scope_iri do
    {:noreply, hint_refresh(state, event.dataset_revision)}
  end

  def handle_info(:refresh_projection, state) do
    state = %{state | refresh_scheduled?: false}

    case state.refresh.(state.authority, state.hinted_revision) do
      {:ok, result} ->
        case evaluated_revision(result) do
          revision when is_integer(revision) and revision >= state.last_revision ->
            send(state.owner, {:projection_refreshed, result})

            {:noreply,
             %{
               state
               | last_revision: revision,
                 hinted_revision: max(revision, state.hinted_revision)
             }}

          _invalid ->
            send(state.owner, {:projection_refresh_failed, :invalid_revision})
            {:noreply, state}
        end

      {:error, %Error{kind: :unauthorized} = error} ->
        send(state.owner, {:projection_inaccessible, error})
        {:noreply, state}

      {:error, %Error{} = error} ->
        send(state.owner, {:projection_refresh_failed, error})
        {:noreply, state}

      _invalid ->
        send(state.owner, {:projection_refresh_failed, :invalid_result})
        {:noreply, state}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp hint_refresh(state, revision) when revision > state.last_revision do
    state = %{state | hinted_revision: max(state.hinted_revision, revision)}

    if state.refresh_scheduled? do
      state
    else
      Process.send_after(self(), :refresh_projection, state.debounce_ms)
      %{state | refresh_scheduled?: true}
    end
  end

  defp hint_refresh(state, _revision), do: state
  defp evaluated_revision(%ProjectionEnvelope{dataset_revision: revision}), do: revision
  defp evaluated_revision(%QueryResult{dataset_revision: revision}), do: revision
  defp evaluated_revision(%{dataset_revision: revision}), do: revision
  defp evaluated_revision(_result), do: nil

  defp subscription_scope?(scope_iri) do
    String.contains?(scope_iri, [
      "/scope/factory/",
      "/scope/repository/",
      "/repository/",
      "/goal/",
      "/attempt/"
    ])
  end

  defp monotonic, do: System.monotonic_time(:millisecond)
end
