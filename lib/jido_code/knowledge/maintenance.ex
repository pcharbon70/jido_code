defmodule JidoCode.Knowledge.Maintenance do
  @moduledoc """
  Serialized, fixed maintenance commands for the embedded graph store.
  """

  use GenServer

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.StoreServer

  @default_timeout 120_000

  def start_link(options \\ []) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec backup(keyword()) :: {:ok, struct()} | {:error, Error.t()}
  def backup(options \\ []) when is_list(options), do: backup(__MODULE__, options)

  @spec backup(GenServer.server(), keyword()) :: {:ok, struct()} | {:error, Error.t()}
  def backup(server, options) when is_list(options) do
    call(server, :backup, options)
  end

  @spec export(:nquads | :trig, keyword()) :: {:ok, struct()} | {:error, Error.t()}
  def export(format, options \\ []) when format in [:nquads, :trig] and is_list(options) do
    export(__MODULE__, format, options)
  end

  @spec export(GenServer.server(), :nquads | :trig, keyword()) ::
          {:ok, struct()} | {:error, Error.t()}
  def export(server, format, options) when is_list(options) do
    call(server, {:export, format}, options)
  end

  @spec integrity(keyword()) :: {:ok, struct()} | {:error, Error.t()}
  def integrity(options \\ []) when is_list(options), do: integrity(__MODULE__, options)

  @spec integrity(GenServer.server(), keyword()) :: {:ok, struct()} | {:error, Error.t()}
  def integrity(server, options) when is_list(options) do
    call(server, :integrity, options)
  end

  @spec restore(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def restore(artifact_id, options \\ []) when is_binary(artifact_id) and is_list(options) do
    restore(__MODULE__, artifact_id, options)
  end

  @spec restore(GenServer.server(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def restore(server, artifact_id, options) when is_binary(artifact_id) and is_list(options) do
    if Keyword.get(options, :confirm) == artifact_id do
      call(server, {:restore, artifact_id}, options)
    else
      {:error, Error.new(:invalid_input, :confirm_restore)}
    end
  end

  @spec retention_candidates(non_neg_integer(), keyword()) ::
          {:ok, [String.t()]} | {:error, Error.t()}
  def retention_candidates(keep_latest, options \\ [])
      when is_integer(keep_latest) and is_list(options) do
    retention_candidates(__MODULE__, keep_latest, options)
  end

  @spec retention_candidates(GenServer.server(), non_neg_integer(), keyword()) ::
          {:ok, [String.t()]} | {:error, Error.t()}
  def retention_candidates(server, keep_latest, options) when is_list(options) do
    call(server, {:retention_candidates, keep_latest}, options)
  end

  @impl true
  def init(options) do
    {:ok, %{store_server: Keyword.get(options, :store_server, StoreServer)}}
  end

  @impl true
  def handle_call(:backup, _from, state) do
    {:reply, StoreServer.request(state.store_server, :backup, @default_timeout), state}
  end

  def handle_call({:export, format}, _from, state) do
    {:reply, StoreServer.request(state.store_server, {:export, format}, @default_timeout), state}
  end

  def handle_call(:integrity, _from, state) do
    {:reply, StoreServer.request(state.store_server, :integrity, @default_timeout), state}
  end

  def handle_call({:restore, artifact_id}, _from, state) do
    result =
      with {:ok, _receipt} <-
             StoreServer.request(
               state.store_server,
               {:enter_maintenance, :restore},
               @default_timeout
             ) do
        StoreServer.request(state.store_server, {:restore, artifact_id}, @default_timeout)
      end

    {:reply, result, state}
  end

  def handle_call({:retention_candidates, keep_latest}, _from, state) do
    {:reply,
     StoreServer.request(
       state.store_server,
       {:retention_candidates, keep_latest},
       @default_timeout
     ), state}
  end

  defp call(server, request, options) do
    timeout = Keyword.get(options, :caller_timeout, @default_timeout + 1_000)
    GenServer.call(server, request, timeout)
  catch
    :exit, {:timeout, _details} -> {:error, Error.new(:timeout, :maintenance_request)}
    :exit, _reason -> {:error, Error.new(:unavailable, :maintenance_request)}
  end
end
