defmodule JidoCode.Runtime.Version do
  @moduledoc "Version and mixed-attempt compatibility policy for execution runtimes."

  @jido_version "2.3.2"
  @contract_version "1.0.0"
  @current "jido:#{@jido_version}/runtime-contract:#{@contract_version}"

  @spec current() :: String.t()
  def current, do: @current

  @spec dependency_versions() :: map()
  def dependency_versions do
    %{jido: @jido_version, runtime_contract: @contract_version, storage: :ephemeral_ets}
  end

  @spec start_compatible?(String.t()) :: boolean()
  def start_compatible?(version), do: version == @current

  @spec recovery_action(String.t(), [String.t()]) :: :resume | :abandon
  def recovery_action(recorded_version, available_versions) when is_list(available_versions) do
    if recorded_version in available_versions, do: :resume, else: :abandon
  end
end
