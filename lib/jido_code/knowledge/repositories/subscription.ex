defmodule JidoCode.Knowledge.Repositories.Subscription do
  @moduledoc """
  Revision-hint subscription for repository catalog projections.

  Catalog and policy changes normally route through factory scope while
  observation changes route through repository scope. This process listens to
  both and treats every event only as a prompt to rerun the authorized bounded
  projection query.
  """

  use GenServer

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.ChangeEvent
  alias JidoCode.Knowledge.ChangeFeed
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ProjectionEnvelope
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @families [:factory_catalog, :factory_policy, :observation_batch]

  def start_link(options) when is_list(options) do
    case Keyword.get(options, :name) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec last_revision(GenServer.server()) :: non_neg_integer()
  def last_revision(server), do: GenServer.call(server, :last_revision)

  @spec reconnect(GenServer.server(), non_neg_integer()) :: :ok
  def reconnect(server, revision), do: GenServer.cast(server, {:reconnect, revision})

  @impl true
  def init(options) do
    scopes = Keyword.fetch!(options, :scope_iris)
    authority = Keyword.fetch!(options, :authority)
    refresh = Keyword.fetch!(options, :refresh)
    pubsub = Keyword.get(options, :pubsub, JidoCode.PubSub)
    last_revision = Keyword.get(options, :last_revision, 0)

    with true <- is_list(scopes) and length(scopes) in 1..3,
         true <- length(scopes) == length(Enum.uniq(scopes)),
         true <- Enum.all?(scopes, &(ResourceIdentity.validate(&1) == :ok)),
         true <- match?(%AuthorityContext{}, authority),
         true <- is_function(refresh, 2),
         true <- is_integer(last_revision) and last_revision >= 0,
         :ok <- subscribe(scopes, pubsub) do
      {:ok,
       %{
         scopes: scopes,
         authority: authority,
         refresh: refresh,
         owner: Keyword.get(options, :owner, self()),
         last_revision: last_revision,
         hinted_revision: last_revision,
         scheduled?: false,
         debounce_ms: Keyword.get(options, :debounce_ms, 10)
       }}
    else
      {:error, %Error{} = error} -> {:stop, error}
      _invalid -> {:stop, Error.new(:invalid_input, :repository_subscription)}
    end
  end

  @impl true
  def handle_call(:last_revision, _from, state), do: {:reply, state.last_revision, state}

  @impl true
  def handle_cast({:reconnect, revision}, state)
      when is_integer(revision) and revision >= 0 do
    {:noreply, hint(state, revision)}
  end

  @impl true
  def handle_info({:jido_code_change, %ChangeEvent{} = event}, state) do
    if event.scope_iri in state.scopes and relevant?(event) do
      {:noreply, hint(state, event.dataset_revision)}
    else
      {:noreply, state}
    end
  end

  def handle_info(:refresh_repository_projection, state) do
    state = %{state | scheduled?: false}

    case state.refresh.(state.authority, state.hinted_revision) do
      {:ok, result} ->
        case evaluated_revision(result) do
          revision when is_integer(revision) and revision >= state.last_revision ->
            send(state.owner, {:repository_projection_refreshed, result})

            {:noreply,
             %{
               state
               | last_revision: revision,
                 hinted_revision: max(revision, state.hinted_revision)
             }}

          _invalid ->
            send(state.owner, {:repository_projection_refresh_failed, :invalid_revision})
            {:noreply, state}
        end

      {:error, %Error{kind: :unauthorized} = error} ->
        send(state.owner, {:repository_projection_inaccessible, error})
        {:noreply, state}

      {:error, %Error{} = error} ->
        send(state.owner, {:repository_projection_refresh_failed, error})
        {:noreply, state}

      _invalid ->
        send(state.owner, {:repository_projection_refresh_failed, :invalid_result})
        {:noreply, state}
    end
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp subscribe(scopes, pubsub) do
    Enum.reduce_while(scopes, :ok, fn scope, :ok ->
      case ChangeFeed.subscribe(scope, pubsub) do
        :ok -> {:cont, :ok}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp relevant?(event) do
    Enum.any?(event.affected_graphs, &(&1.family in @families))
  end

  defp hint(state, revision) when revision > state.last_revision do
    state = %{state | hinted_revision: max(state.hinted_revision, revision)}

    if state.scheduled? do
      state
    else
      Process.send_after(self(), :refresh_repository_projection, state.debounce_ms)
      %{state | scheduled?: true}
    end
  end

  defp hint(state, _revision), do: state
  defp evaluated_revision(%ProjectionEnvelope{dataset_revision: revision}), do: revision
  defp evaluated_revision(%QueryResult{dataset_revision: revision}), do: revision
  defp evaluated_revision(%{dataset_revision: revision}), do: revision
  defp evaluated_revision(%{receipt: %{dataset_revision: revision}}), do: revision
  defp evaluated_revision(_result), do: nil
end
