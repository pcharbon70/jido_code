defmodule JidoCode.Factory.Sandbox.Workload do
  @moduledoc "Closed workload binding that prevents command risk from being downgraded."

  alias JidoCode.Factory.AdapterError

  @workloads [
    :read_only_analysis,
    :non_executing_transformation,
    :build,
    :test,
    :hook,
    :package_hook,
    :git_hook,
    :workflow,
    :build_script,
    :compiler,
    :native_tool,
    :generated_binary,
    :unknown_high_risk
  ]

  @spec authorize_command(atom(), map(), [String.t()]) ::
          :ok | {:error, AdapterError.t()}
  def authorize_command(provisioned_workload, command, allowlist)
      when provisioned_workload in @workloads and is_map(command) and is_list(allowlist) do
    with ^provisioned_workload <- command[:workload],
         name when is_binary(name) <- command[:name],
         true <- name in allowlist,
         usage when is_map(usage) <- command[:usage] do
      :ok
    else
      _invalid -> unauthorized()
    end
  end

  def authorize_command(_workload, _command, _allowlist), do: unauthorized()

  defp unauthorized,
    do: {:error, AdapterError.new(:unauthorized, :sandbox_workload_boundary)}
end
