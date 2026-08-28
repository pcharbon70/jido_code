defmodule JidoCode.Runtime.RepositoryWikiMaintainerSupervisor do
  @moduledoc "Starts disposable repository wiki maintainers under a DynamicSupervisor."

  alias JidoCode.Runtime.RepositoryWikiMaintainerWorker

  def start_child(supervisor, options) when is_atom(supervisor) and is_list(options),
    do: DynamicSupervisor.start_child(supervisor, {RepositoryWikiMaintainerWorker, options})

  def terminate_child(supervisor, pid) when is_atom(supervisor) and is_pid(pid),
    do: DynamicSupervisor.terminate_child(supervisor, pid)

  def active(supervisor) when is_atom(supervisor) do
    supervisor
    |> DynamicSupervisor.which_children()
    |> Enum.map(fn {_id, pid, _type, _modules} -> pid end)
    |> Enum.filter(&is_pid/1)
  end
end
