defmodule JidoCode.Knowledge.Admin do
  @moduledoc """
  Bounded internal operator commands for the authoritative graph store.

  This boundary accepts artifact identities and fixed formats, never raw paths,
  SPARQL, RDF payloads, or backend handles.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.StoreServer

  @type command :: :health | :integrity | :backup | :export | :restore

  @spec execute(command(), keyword()) :: {:ok, term()} | {:error, Error.t()}
  def execute(command, options \\ [])

  def execute(command, options) when is_list(options) do
    with :ok <- validate_options(command, options) do
      do_execute(command, options)
    end
  end

  def execute(_command, _options), do: {:error, Error.new(:invalid_input, :admin_command)}

  defp do_execute(:health, options) do
    server = Keyword.get(options, :store_server, StoreServer)
    {:ok, StoreServer.summary(server)}
  catch
    :exit, _reason -> {:error, Error.new(:unavailable, :admin_health)}
  end

  defp do_execute(:integrity, options) do
    maintenance = Keyword.get(options, :maintenance, Maintenance)
    Maintenance.integrity(maintenance, [])
  end

  defp do_execute(:backup, options) do
    maintenance = Keyword.get(options, :maintenance, Maintenance)
    Maintenance.backup(maintenance, [])
  end

  defp do_execute(:export, options) do
    maintenance = Keyword.get(options, :maintenance, Maintenance)
    Maintenance.export(maintenance, Keyword.fetch!(options, :format), [])
  end

  defp do_execute(:restore, options) do
    maintenance = Keyword.get(options, :maintenance, Maintenance)
    artifact_id = Keyword.fetch!(options, :artifact)

    Maintenance.restore(maintenance, artifact_id, confirm: Keyword.fetch!(options, :confirm))
  end

  defp do_execute(_command, _options) do
    {:error, Error.new(:invalid_input, :admin_command)}
  end

  defp validate_options(:health, options), do: only_keys(options, [:store_server])
  defp validate_options(:integrity, options), do: only_keys(options, [:maintenance])
  defp validate_options(:backup, options), do: only_keys(options, [:maintenance])

  defp validate_options(:export, options) do
    with :ok <- only_keys(options, [:format, :maintenance]),
         true <- Keyword.get(options, :format) in [:nquads, :trig] do
      :ok
    else
      _invalid -> {:error, Error.new(:invalid_input, :admin_export)}
    end
  end

  defp validate_options(:restore, options) do
    with :ok <- only_keys(options, [:artifact, :confirm, :maintenance]),
         artifact when is_binary(artifact) <- Keyword.get(options, :artifact),
         true <- artifact != "" and Keyword.get(options, :confirm) == artifact do
      :ok
    else
      _invalid -> {:error, Error.new(:invalid_input, :admin_restore)}
    end
  end

  defp validate_options(_command, _options) do
    {:error, Error.new(:invalid_input, :admin_command)}
  end

  defp only_keys(options, allowed) do
    keys = Keyword.keys(options)

    if Keyword.keyword?(options) and keys == Enum.uniq(keys) and keys -- allowed == [] do
      :ok
    else
      {:error, Error.new(:invalid_input, :admin_command)}
    end
  end
end
