defmodule JidoCode.Factory.RepositoryWiki.MixSandbox do
  @moduledoc "Fixed controller-owned sandbox observation boundary for unresolved Mix facts."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Sandbox
  alias JidoCode.Factory.Sandbox.IsolationProfile
  alias JidoCode.Factory.Sandbox.Request
  alias JidoCode.Knowledge.Error

  @profile "mix-sandbox/1.0.0"
  @command "jido-wiki-mix-introspect"
  @environment %{
    "HOME" => "/nonexistent",
    "HEX_HOME" => "/nonexistent",
    "MIX_ENV" => "prod",
    "MIX_HOME" => "/nonexistent",
    "MIX_TARGET" => "host"
  }
  @write_root ".jido-code/wiki-mix"
  @mix_path @write_root <> "/source/mix.exs"
  @lock_path @write_root <> "/source/mix.lock"
  @image_digest "sha256:" <>
                  Base.encode16(:crypto.hash(:sha256, "jido-wiki-mix-sandbox-image/1.0.0"),
                    case: :lower
                  )
  @tool_digest "sha256:" <>
                 Base.encode16(:crypto.hash(:sha256, "jido-wiki-mix-introspector/1.0.0"),
                   case: :lower
                 )
  @syscall_digest "sha256:" <>
                    Base.encode16(:crypto.hash(:sha256, "jido-wiki-mix-syscalls/1.0.0"),
                      case: :lower
                    )
  @limits %{
    cpu_ms: 10_000,
    memory_bytes: 536_870_912,
    process_count: 32,
    disk_bytes: 268_435_456,
    output_bytes: 12_000,
    timeout_ms: 30_000
  }

  @spec profile() :: map()
  def profile do
    {:ok, isolation} =
      IsolationProfile.new(%{
        tier: :container_sandbox,
        technology: :gvisor,
        image_reference: "https://registry.jido.run/wiki/mix-introspector@" <> @image_digest,
        image_digest: @image_digest,
        tool_digests: %{@command => @tool_digest},
        unprivileged: true,
        read_only_root: true,
        copy_on_write_workspace: true,
        host_filesystem: false,
        docker_socket: false,
        device_access: false,
        ambient_credentials: false,
        capabilities: [],
        no_new_privs: true,
        syscall_policy_digest: @syscall_digest,
        network: :deny,
        mounts: [:workspace, :artifact],
        limits: @limits
      })

    %{
      revision: @profile,
      executable: @command,
      argv: ["--schema", @profile, "--format", "json"],
      environment: @environment,
      source_mount: %{root: @write_root <> "/source", mode: :read_only, immutable: true},
      scratch_mount: %{root: @write_root <> "/scratch", mode: :read_write, disposable: true},
      credentials: :deny,
      user_configuration: :deny,
      project_tools: :deny,
      hooks: :deny,
      shells: :deny,
      dependency_fetch: :deny,
      network: :deny,
      limits: @limits,
      isolation: isolation,
      digest: IsolationProfile.digest(isolation)
    }
  end

  @spec observe(map(), map(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def observe(static, attributes, options \\ [])

  def observe(static, attributes, options)
      when is_map(static) and is_map(attributes) and is_list(options) do
    sandbox_module = Keyword.get(options, :sandbox_module, Sandbox)
    adapter_module = Keyword.get(options, :adapter_module)
    adapter = Keyword.get(options, :adapter)
    authority = Keyword.get(options, :authority)
    request = attributes[:sandbox_request]
    snapshot = attributes[:snapshot]

    try do
      with :ok <- admission(static, attributes),
           :ok <- fixed_request(request),
           :ok <- fixed_snapshot(snapshot, request, static),
           true <- is_atom(sandbox_module) and is_atom(adapter_module),
           true <- not is_nil(adapter) and not is_nil(authority),
           {:ok, provisioned} <-
             sandbox_module.provision(adapter_module, adapter, request, authority: authority),
           {:ok, materialized} <-
             sandbox_module.materialize(adapter_module, adapter, request, snapshot,
               authority: authority
             ),
           {:ok, executed} <-
             sandbox_module.execute(
               adapter_module,
               adapter,
               request,
               fixed_command(static, attributes),
               authority: authority
             ),
           {:ok, collected} <-
             sandbox_module.collect(adapter_module, adapter, request, authority: authority),
           true <- collected.details.content_digest == materialized.details.content_digest,
           {:ok, observation} <- normalize(executed, provisioned, static, attributes),
           {:ok, _destroyed} <-
             sandbox_module.destroy(adapter_module, adapter, request, authority: authority) do
        {:ok, observation}
      else
        {:error, %Error{} = error} ->
          destroy_best_effort(sandbox_module, adapter_module, adapter, request, authority)
          {:error, error}

        {:error, %AdapterError{} = error} ->
          destroy_best_effort(sandbox_module, adapter_module, adapter, request, authority)
          adapter_error(error)

        _invalid ->
          destroy_best_effort(sandbox_module, adapter_module, adapter, request, authority)
          invalid()
      end
    rescue
      _error ->
        destroy_best_effort(sandbox_module, adapter_module, adapter, request, authority)
        invalid()
    end
  end

  def observe(_static, _attributes, _options), do: invalid()

  defp admission(static, attributes) do
    unresolved =
      static
      |> Map.get(:fields, [])
      |> Enum.filter(&(&1[:state] == :dynamic_required))
      |> Enum.map(& &1[:name])
      |> MapSet.new()

    requested = Map.get(attributes, :requested_fields, [])

    cond do
      static[:profile] != "mix-static/1.0.0" or not digest?(static[:digest]) ->
        invalid()

      not digest?(static[:source_digest]) ->
        invalid()

      attributes[:source_digest] != static.source_digest ->
        conflict()

      attributes[:policy_allows_sandbox] != true ->
        unauthorized()

      attributes[:enrollment_state] not in [:manual, :automatic] ->
        unauthorized()

      attributes[:generation_profile] not in [:manual_deterministic, :automatic_deterministic] ->
        unauthorized()

      not is_list(requested) or requested == [] or length(requested) > 128 ->
        invalid()

      not Enum.all?(requested, &(is_binary(&1) and MapSet.member?(unresolved, &1))) ->
        conflict()

      not valid_fence?(attributes[:source_fence]) or
        not prefixed_digest?(attributes[:toolchain_digest]) or
        not is_integer(attributes[:policy_revision]) or attributes.policy_revision < 0 ->
        invalid()

      true ->
        :ok
    end
  end

  defp fixed_request(%Request{} = request) do
    expected_environment = @environment |> Map.keys() |> Enum.sort()
    profile = profile()

    if request.allowed_write_paths == [@write_root] and
         request.command_allowlist == [@command] and
         request.environment_allowlist == expected_environment and
         request.secret_reference_iris == [] and
         IsolationProfile.admits?(profile.isolation, request.limits) and
         request.limits.network == :deny do
      :ok
    else
      unauthorized()
    end
  end

  defp fixed_request(_request), do: invalid()

  defp fixed_snapshot(%{snapshot_iri: snapshot_iri, files: files}, %Request{} = request, static)
       when is_map(files) do
    allowed = MapSet.new([@mix_path, @lock_path])
    paths = Map.keys(files)
    mix_source = files[@mix_path]

    if snapshot_iri == request.base_snapshot_iri and paths != [] and
         Enum.all?(paths, &MapSet.member?(allowed, &1)) and is_binary(mix_source) and
         sha256(mix_source) == static.source_digest and
         Enum.all?(files, fn {_path, content} ->
           is_binary(content) and byte_size(content) <= 262_144
         end) do
      :ok
    else
      conflict()
    end
  end

  defp fixed_snapshot(_snapshot, _request, _static), do: invalid()

  defp fixed_command(static, attributes) do
    %{
      name: @command,
      args: profile().argv ++ ["--source-digest", static.source_digest],
      environment: @environment,
      network: false,
      controller_fence: %{
        source_digest: static.source_digest,
        source_fence: attributes.source_fence,
        toolchain_digest: attributes.toolchain_digest,
        policy_revision: attributes.policy_revision,
        requested_fields: Enum.sort(attributes.requested_fields)
      }
    }
  end

  defp normalize(executed, provisioned, static, attributes) do
    details = executed.details

    with outcome when outcome in [:success, :failure] <- executed.outcome,
         status when is_integer(status) and status in 0..255 <- details[:exit_status],
         true <- is_binary(details[:stdout]) and byte_size(details.stdout) <= @limits.output_bytes,
         {:ok, payload} <- Jason.decode(details.stdout),
         true <- payload["schema"] == @profile,
         true <- payload["source_digest"] == static.source_digest,
         true <- payload["toolchain_digest"] == attributes.toolchain_digest,
         {:ok, fields} <- observed_fields(payload["fields"], attributes.requested_fields),
         {:ok, dependencies} <- observed_dependencies(payload["dependencies"] || []),
         {:ok, diagnostics} <- diagnostics(payload["diagnostics"] || []),
         truncated when is_boolean(truncated) <- payload["truncated"],
         false <- forbidden_payload?(payload) do
      result = %{
        profile: @profile,
        profile_digest: profile().digest,
        source_digest: static.source_digest,
        source_fence: attributes.source_fence,
        toolchain_digest: attributes.toolchain_digest,
        policy_revision: attributes.policy_revision,
        requested_fields: Enum.sort(attributes.requested_fields),
        fields: fields,
        dependencies: dependencies,
        diagnostics: diagnostics,
        status: if(status == 0 and outcome == :success, do: :completed, else: :incomplete),
        exit_status: status,
        truncated: truncated,
        usage: details[:usage] || %{},
        sandbox_provider_ref: provisioned.provider_ref,
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      {:ok, Map.put(result, :digest, term_digest(result))}
    else
      _invalid -> invalid()
    end
  end

  defp observed_fields(values, requested) when is_list(values) and length(values) <= 128 do
    requested = MapSet.new(requested)

    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, result} ->
      with true <- is_map(value),
           name when is_binary(name) <- value["name"],
           true <- byte_size(name) in 1..128 and MapSet.member?(requested, name),
           true <- bounded_value?(value["value"], 16_384),
           true <- value["state"] in [nil, "observed", "unavailable", "unsupported"] do
        normalized = %{
          name: name,
          value: value["value"],
          state: normalize_observed_state(value["state"]),
          authority: :observed,
          confidence: :observed,
          location: nil
        }

        {:cont, {:ok, [normalized | result]}}
      else
        _invalid -> {:halt, invalid()}
      end
    end)
    |> case do
      {:ok, fields} ->
        names = Enum.map(fields, & &1.name)

        if length(names) == length(Enum.uniq(names)),
          do: {:ok, Enum.sort_by(fields, & &1.name)},
          else: invalid()

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp observed_fields(_values, _requested), do: invalid()

  defp observed_dependencies(values) when is_list(values) and length(values) <= 512 do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, result} ->
      with true <- is_map(value),
           name when is_binary(name) <- value["name"],
           true <- Regex.match?(~r/^[a-z][a-z0-9_]{0,127}$/, name),
           true <- bounded_value?(value, 16_384) do
        normalized =
          value
          |> Map.take(~w[name requirement scm environments targets optional override runtime])
          |> Map.put("authority", "observed")

        {:cont, {:ok, [normalized | result]}}
      else
        _invalid -> {:halt, invalid()}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.sort_by(values, & &1["name"])}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp observed_dependencies(_values), do: invalid()

  defp diagnostics(values) when is_list(values) and length(values) <= 256 do
    if Enum.all?(values, &bounded_value?(&1, 2_048)), do: {:ok, values}, else: invalid()
  end

  defp diagnostics(_values), do: invalid()

  defp normalize_observed_state(nil), do: :observed
  defp normalize_observed_state("observed"), do: :observed
  defp normalize_observed_state("unavailable"), do: :unavailable
  defp normalize_observed_state("unsupported"), do: :unsupported

  defp bounded_value?(value, limit) do
    byte_size(:erlang.term_to_binary(value, [:deterministic])) <= limit
  rescue
    _error -> false
  end

  defp forbidden_payload?(value) when is_map(value) do
    Enum.any?(value, fn {key, nested} -> forbidden_key?(key) or forbidden_payload?(nested) end)
  end

  defp forbidden_payload?(value) when is_list(value), do: Enum.any?(value, &forbidden_payload?/1)
  defp forbidden_payload?(_value), do: false

  defp forbidden_key?(key) when is_binary(key),
    do: String.downcase(key) in ["password", "token", "secret", "credential", "host_path", "pid"]

  defp forbidden_key?(_key), do: false

  defp valid_fence?(value) when is_binary(value) and byte_size(value) in 1..256,
    do: Regex.match?(~r/^[a-z0-9][a-z0-9:._-]+$/, value)

  defp valid_fence?(_value), do: false

  defp prefixed_digest?(value) when is_binary(value),
    do: Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp prefixed_digest?(_value), do: false

  defp sha256(value),
    do: value |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  defp term_digest(value),
    do: value |> :erlang.term_to_binary([:deterministic]) |> sha256()

  defp digest?(value) when is_binary(value), do: Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp digest?(_value), do: false

  defp destroy_best_effort(
         sandbox_module,
         adapter_module,
         adapter,
         %Request{} = request,
         authority
       )
       when is_atom(sandbox_module) and is_atom(adapter_module) and not is_nil(adapter) and
              not is_nil(authority) do
    _ = sandbox_module.destroy(adapter_module, adapter, request, authority: authority)
    :ok
  rescue
    _error -> :ok
  end

  defp destroy_best_effort(_sandbox_module, _adapter_module, _adapter, _request, _authority),
    do: :ok

  defp adapter_error(%AdapterError{kind: kind})
       when kind in [:unavailable, :invalid_input, :unauthorized, :conflict, :corrupt, :timeout],
       do: {:error, Error.new(kind, :repository_wiki_mix_sandbox)}

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_mix_sandbox)}
  defp unauthorized, do: {:error, Error.new(:unauthorized, :repository_wiki_mix_sandbox)}
  defp conflict, do: {:error, Error.new(:conflict, :repository_wiki_mix_sandbox)}
end
