defmodule JidoCode.Runtime.JidoHarness.DeveloperLocalLaunch do
  @moduledoc "Validates the explicit local-only contract for one isolated CLI worker."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Credential.CodexLocalConnector
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.Sandbox.IsolationProfile
  alias JidoCode.Runtime.JidoHarness.CodexLocalRelease

  @environment_names ~w[PATH HOME TMPDIR LANG LC_ALL CODEX_HOME]
  @limit_keys ~w[run_count cpu_ms memory_bytes process_count disk_bytes output_bytes wall_ms idle_ms session_turns]a
  @hard_limits ~w[run_count cpu_ms memory_bytes process_count disk_bytes output_bytes wall_ms idle_ms session_turns]a

  @spec build(Request.t(), map(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def build(%Request{} = request, profile, attributes)
      when is_map(profile) and is_map(attributes) do
    worker = attributes[:worker]

    with deployment when deployment in [:developer_local_cli, :developer_local] <-
           profile[:deployment_class],
         true <- profile[:explicit_opt_in] == true,
         false <- profile[:managed_eligible],
         :ok <- validate_consent(profile, attributes[:consent], request),
         :ok <- validate_worker(worker, request),
         :ok <- validate_environment(profile, attributes[:environment]),
         :ok <- validate_egress(profile, attributes[:provider_egress]),
         :ok <- validate_credential_reference(attributes[:credential_reference_iri]),
         {:ok, attachment_digest} <- validate_attachment(profile, attributes),
         :ok <- version(attributes[:cli_version]),
         :ok <- version(attributes[:provider_version]),
         {:ok, limits} <- validate_limits(attributes[:limits], profile),
         :ok <- validate_exclusions(attributes) do
      {:ok,
       %{
         deployment_class: deployment,
         explicit_opt_in: true,
         managed_eligible: false,
         workspace_path: worker.workspace_path,
         snapshot_iri: request.snapshot_iri,
         executable: worker.cli_path,
         executable_digest: worker.cli_digest,
         environment: attributes.environment,
         env_mode: :replace,
         provider_egress: attributes.provider_egress,
         credential_reference_iri: attributes.credential_reference_iri,
         credential_attachment_digest: attachment_digest,
         cli_version: attributes.cli_version,
         provider_version: attributes.provider_version,
         limits: limits,
         enforcement: enforcement_receipt(),
         outer_worker: %{
           tier: worker.isolation_profile.tier,
           isolation_profile_digest: IsolationProfile.digest(worker.isolation_profile),
           process_namespace: :isolated,
           disposable: true,
           store_handle: false,
           publication_credentials: false,
           ssh_agent: false,
           docker_socket: false,
           unrelated_repositories: false
         },
         extensions: [],
         mcp_servers: [],
         skills: [],
         provider_configuration: [],
         additional_directories: []
       }}
    else
      _invalid -> invalid(:jido_harness_developer_local_launch)
    end
  rescue
    _error -> invalid(:jido_harness_developer_local_launch)
  end

  def build(_request, _profile, _attributes),
    do: invalid(:jido_harness_developer_local_launch)

  @spec enforcement_receipt() :: map()
  def enforcement_receipt do
    %{
      outer: Map.new(@hard_limits, &{&1, :hard}),
      cli_internal_turns: :unavailable,
      tokens: :unavailable,
      cost: :unavailable,
      subscription_usage: :observed_only
    }
  end

  defp validate_worker(
         %{
           snapshot_iri: snapshot_iri,
           workspace_path: workspace_path,
           cli_path: cli_path,
           cli_digest: cli_digest,
           isolation_profile: %IsolationProfile{} = isolation,
           process_namespace: :isolated,
           disposable: true,
           store_handle: false,
           publication_credentials: false,
           ssh_agent: false,
           docker_socket: false,
           unrelated_repositories: false
         },
         request
       ) do
    with true <- snapshot_iri == request.snapshot_iri,
         true <- is_binary(workspace_path) and Path.type(workspace_path) == :absolute,
         true <- File.dir?(workspace_path),
         true <- is_binary(cli_path) and Path.type(cli_path) == :absolute,
         true <- valid_digest?(cli_digest),
         :micro_vm <- isolation.tier,
         :firecracker <- isolation.technology,
         :deny <- isolation.network,
         false <- isolation.ambient_credentials,
         false <- isolation.host_filesystem,
         false <- isolation.docker_socket do
      :ok
    else
      _invalid -> :error
    end
  end

  defp validate_worker(_worker, _request), do: :error

  defp validate_environment(%{name: :codex_dga1}, environment) do
    if environment == CodexLocalConnector.fixed_environment(), do: :ok, else: :error
  end

  defp validate_environment(_profile, environment) when is_map(environment) do
    names = Map.keys(environment)

    if names != [] and Enum.all?(names, &(&1 in @environment_names)) and
         Enum.all?(environment, fn {name, value} ->
           is_binary(name) and is_binary(value) and byte_size(value) in 1..1_024
         end) and Map.has_key?(environment, "PATH") and Map.has_key?(environment, "HOME") and
         Map.has_key?(environment, "TMPDIR") do
      :ok
    else
      :error
    end
  end

  defp validate_environment(_profile, _environment), do: :error

  defp validate_egress(%{name: :codex_dga1}, %{
         mode: :brokered,
         destinations: [destination],
         parent: :provider_only,
         tool_descendants: :deny
       }) do
    if destination == CodexLocalRelease.provider_audience(), do: :ok, else: :error
  end

  defp validate_egress(%{name: :codex_dga1}, _egress), do: :error

  defp validate_egress(_profile, %{mode: :brokered, destinations: destinations})
       when is_list(destinations) and length(destinations) in 1..10 do
    if Enum.all?(destinations, &provider_destination?/1), do: :ok, else: :error
  end

  defp validate_egress(_profile, _egress), do: :error

  defp validate_consent(%{name: :codex_dga1}, consent, request) when is_map(consent) do
    if consent[:actor_iri] == request.actor_iri and
         consent[:repository_iri] == request.repository_iri and
         consent[:task_iri] == request.task_iri and consent[:attempt_iri] == request.attempt_iri and
         consent[:lease_iri] == request.lease_iri and
         consent[:fencing_token] == request.fencing_token and
         consent[:profile_digest] == CodexLocalRelease.manifest().profile_digest and
         consent[:billing_classification] == :subscription and consent[:purpose] == :execution and
         is_binary(consent[:consent_digest]) and is_binary(consent[:credential_reference_iri]) and
         is_integer(consent[:credential_generation]) and consent.credential_generation > 0 do
      :ok
    else
      :error
    end
  end

  defp validate_consent(_profile, true, _request), do: :ok
  defp validate_consent(_profile, _consent, _request), do: :error

  defp validate_attachment(%{name: :codex_dga1}, attributes) do
    attachment = attributes[:credential_attachment]
    consent = attributes[:consent]

    if is_map(attachment) and attachment[:state] == :active and
         attachment[:credential_reference_iri] == attributes[:credential_reference_iri] and
         attachment[:credential_reference_iri] == consent[:credential_reference_iri] and
         attachment[:credential_generation] == consent[:credential_generation] and
         attachment[:profile_digest] == CodexLocalRelease.manifest().profile_digest and
         attachment[:mount_point] == CodexLocalConnector.mount_point() and
         attachment[:mount_mode] == :read_only and
         attachment[:parent_access] == :provider_authentication_only and
         attachment[:tool_descendant_access] == :denied and
         attachment[:source_path_retained] == false and
         attachment[:reusable_material_exported] == false and
         digest?(attachment[:attachment_digest]) do
      {:ok, attachment.attachment_digest}
    else
      :error
    end
  end

  defp validate_attachment(_profile, _attributes), do: {:ok, nil}

  defp provider_destination?(value) when is_binary(value) and byte_size(value) <= 512 do
    case URI.parse(value) do
      %URI{
        scheme: "https",
        host: host,
        userinfo: nil,
        fragment: nil,
        query: nil,
        port: port
      }
      when is_binary(host) and port in [nil, 443] ->
        true

      _other ->
        false
    end
  end

  defp provider_destination?(_value), do: false

  defp validate_credential_reference(value) when is_binary(value) and byte_size(value) <= 512 do
    if String.starts_with?(value, "https://jido.run/id/"), do: :ok, else: :error
  end

  defp validate_credential_reference(_value), do: :error

  defp validate_limits(limits, profile) when is_map(limits) do
    if MapSet.new(Map.keys(limits)) == MapSet.new(@limit_keys) and
         Enum.all?(limits, fn
           {:run_count, value} -> valid_turn_limit?(profile, :run_count, value)
           {:session_turns, value} -> valid_turn_limit?(profile, :session_turns, value)
           {_key, value} -> is_integer(value) and value in 1..3_600_000_000
         end) do
      {:ok, Map.take(limits, @limit_keys)}
    else
      :error
    end
  end

  defp validate_limits(_limits, _profile), do: :error

  defp valid_turn_limit?(%{name: :codex_dga1}, key, value)
       when key in [:run_count, :session_turns],
       do: value == 2

  defp valid_turn_limit?(_profile, :run_count, value), do: value == 1
  defp valid_turn_limit?(_profile, :session_turns, value), do: value in 1..10

  defp validate_exclusions(attributes) do
    if Enum.all?(
         [:extensions, :mcp_servers, :skills, :provider_configuration, :additional_directories],
         &(Map.get(attributes, &1, []) == [])
       ) do
      :ok
    else
      :error
    end
  end

  defp valid_digest?(value) when is_binary(value),
    do: Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp valid_digest?(_value), do: false

  defp digest?(value) when is_binary(value), do: Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp digest?(_value), do: false

  defp version(value) when is_binary(value) and byte_size(value) in 1..128, do: :ok
  defp version(_value), do: :error

  defp invalid(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end
