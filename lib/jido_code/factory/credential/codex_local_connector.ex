defmodule JidoCode.Factory.Credential.CodexLocalConnector do
  @moduledoc "Trusted parent-only attachment of one existing local Codex login reference."

  use GenServer
  import Bitwise

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Credential.Permit
  alias JidoCode.Runtime.JidoHarness.CodexLocalRelease

  @mount_point "/run/jido-code/codex-home"
  @fixed_environment %{
    "PATH" => "/usr/bin:/bin",
    "HOME" => "/run/jido-code/home",
    "TMPDIR" => "/run/jido-code/tmp",
    "CODEX_HOME" => @mount_point,
    "LANG" => "C.UTF-8"
  }
  @reasons ~w[cancellation expiry supersession termination worker_loss]a

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, options, Keyword.take(options, [:name]))
  end

  @spec identity(GenServer.server()) :: {:ok, map()} | {:error, AdapterError.t()}
  def identity(server), do: GenServer.call(server, :identity)

  @spec execute(GenServer.server(), Permit.t(), term(), map()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def execute(server, %Permit{} = permit, delivery, payload) when is_map(payload) do
    GenServer.call(server, {:execute, permit, delivery, payload}, :infinity)
  end

  def execute(_server, _permit, _delivery, _payload), do: invalid(:codex_local_attachment)

  @spec attachment(GenServer.server(), String.t(), map()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def attachment(server, attachment_id, current)
      when is_binary(attachment_id) and is_map(current) do
    GenServer.call(server, {:attachment, attachment_id, current})
  end

  def attachment(_server, _attachment_id, _current), do: invalid(:codex_local_attachment)

  @spec revoke(GenServer.server(), String.t(), atom(), map()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def revoke(server, attachment_id, reason, current)
      when is_binary(attachment_id) and reason in @reasons and is_map(current) do
    GenServer.call(server, {:revoke, attachment_id, reason, current}, :infinity)
  end

  def revoke(_server, _attachment_id, _reason, _current),
    do: invalid(:codex_local_attachment_revoke)

  @spec fixed_environment() :: map()
  def fixed_environment, do: @fixed_environment

  @spec mount_point() :: String.t()
  def mount_point, do: @mount_point

  @impl true
  def init(options) do
    root = Keyword.get(options, :credential_root)
    references = Keyword.get(options, :references)
    revoker = Keyword.get(options, :revoker, fn _attachment, _reason -> :ok end)

    with :ok <- approved_root(root),
         true <- is_map(references) and map_size(references) in 1..16,
         :ok <- references(references, root),
         true <- is_function(revoker, 2) do
      {:ok, %{root: root, references: references, active: %{}, revoker: revoker}}
    else
      _invalid -> {:stop, AdapterError.new(:invalid_input, :codex_local_connector)}
    end
  end

  @impl true
  def handle_call(:identity, _from, state), do: {:reply, {:ok, connector_identity()}, state}

  def handle_call({:execute, permit, delivery, payload}, _from, state) do
    with {:local_cli_reference, reference_iri} <- delivery,
         true <- permit.credential_class == :local_cli_reference,
         true <- permit.credential_reference_iri == reference_iri,
         {:ok, reference} <- Map.fetch(state.references, reference_iri),
         :ok <- payload(permit, payload, reference),
         :ok <- secure_reference(state.root, reference.path, payload.workspace_path),
         attachment <- attachment_receipt(permit, payload, reference_iri),
         false <- Map.has_key?(state.active, attachment.attachment_id) do
      private = %{
        receipt: attachment,
        source_path: reference.path,
        attempt_iri: permit.attempt_iri,
        fencing_token: permit.fencing_token,
        credential_generation: reference.generation,
        expires_at: permit.expires_at
      }

      {:reply, {:ok, attachment}, put_in(state, [:active, attachment.attachment_id], private)}
    else
      true -> {:reply, conflict(:codex_local_attachment), state}
      _invalid -> {:reply, unauthorized(:codex_local_attachment), state}
    end
  rescue
    _error -> {:reply, unavailable(:codex_local_attachment), state}
  end

  def handle_call({:attachment, attachment_id, current}, _from, state) do
    with {:ok, private} <- Map.fetch(state.active, attachment_id),
         :ok <- current(private, current),
         %DateTime{} = at <- current[:at],
         true <- DateTime.compare(at, private.expires_at) == :lt do
      {:reply, {:ok, private.receipt}, state}
    else
      _invalid -> {:reply, unauthorized(:codex_local_attachment), state}
    end
  end

  def handle_call({:revoke, attachment_id, reason, current}, _from, state) do
    with {:ok, private} <- Map.fetch(state.active, attachment_id),
         :ok <- current(private, current),
         true <- current[:semantic_transition_committed] == true,
         :ok <- state.revoker.(private, reason) do
      receipt = %{
        attachment_id: attachment_id,
        status: :revoked,
        reason: reason,
        source_destroyed: true,
        revoked_digest: digest({attachment_id, reason, private.receipt.attachment_digest})
      }

      {:reply, {:ok, receipt}, update_in(state, [:active], &Map.delete(&1, attachment_id))}
    else
      _invalid -> {:reply, unauthorized(:codex_local_attachment_revoke), state}
    end
  rescue
    _error -> {:reply, unavailable(:codex_local_attachment_revoke), state}
  end

  @impl true
  def terminate(reason, state) do
    Enum.each(state.active, fn {_id, private} ->
      _ = state.revoker.(private, normalize_termination(reason))
    end)

    :ok
  end

  defp connector_identity do
    %{
      name: "jido_code_codex_local_connector",
      digest: "sha256:" <> CodexLocalRelease.revisions().credential,
      trusted: true,
      delivery: :direct,
      credential_classes: [:local_cli_reference]
    }
  end

  defp payload(permit, payload, reference) do
    expected_keys = [
      :operation,
      :profile_digest,
      :credential_generation,
      :workspace_path,
      :attempt_iri,
      :fencing_token,
      :provider_audience,
      :environment,
      :isolation
    ]

    isolation = payload[:isolation]

    if MapSet.new(Map.keys(payload)) == MapSet.new(expected_keys) and
         payload[:operation] == :attach_codex_login and
         payload[:profile_digest] == CodexLocalRelease.manifest().profile_digest and
         payload[:credential_generation] == reference.generation and
         payload[:attempt_iri] == permit.attempt_iri and
         payload[:fencing_token] == permit.fencing_token and
         payload[:provider_audience] == CodexLocalRelease.provider_audience() and
         payload[:environment] == @fixed_environment and
         valid_workspace?(payload[:workspace_path]) and
         isolation == %{
           parent_authentication: true,
           tool_descendant_credential_access: false,
           credential_mount: :read_only,
           credential_mount_outside_workspace: true,
           process_namespace: :isolated,
           host_home: false,
           ssh_agent: false,
           docker_socket: false,
           publication_credentials: false,
           arbitrary_egress: false
         } do
      :ok
    else
      :error
    end
  end

  defp attachment_receipt(permit, payload, reference_iri) do
    material = %{
      permit_id: permit.id,
      credential_reference_iri: reference_iri,
      credential_generation: payload.credential_generation,
      profile_digest: payload.profile_digest,
      attempt_iri: permit.attempt_iri,
      fencing_token: permit.fencing_token,
      mount_point: @mount_point,
      provider_audience: payload.provider_audience
    }

    attachment_digest = digest(material)

    Map.merge(material, %{
      attachment_id: "sha256:" <> attachment_digest,
      attachment_digest: attachment_digest,
      state: :active,
      mount_mode: :read_only,
      parent_access: :provider_authentication_only,
      tool_descendant_access: :denied,
      egress: %{parent: :brokered_provider_only, tool_descendants: :deny},
      environment: @fixed_environment,
      source_path_retained: false,
      reusable_material_exported: false
    })
  end

  defp approved_root(root) when is_binary(root) do
    with true <- Path.type(root) == :absolute and Path.expand(root) == root,
         {:ok, %File.Stat{type: :directory, mode: mode}} <- File.lstat(root),
         true <- (mode &&& 0o077) == 0 do
      :ok
    else
      _invalid -> :error
    end
  end

  defp approved_root(_root), do: :error

  defp references(references, root) do
    if Enum.all?(references, fn {iri, reference} ->
         is_binary(iri) and String.starts_with?(iri, "https://jido.run/id/") and
           match?(
             %{path: path, generation: generation}
             when is_binary(path) and is_integer(generation) and generation > 0,
             reference
           ) and
           Path.type(reference.path) == :absolute and
           Path.expand(reference.path) == reference.path and
           descendant?(reference.path, root)
       end),
       do: :ok,
       else: :error
  end

  defp secure_reference(root, path, workspace) do
    with true <- descendant?(path, root),
         false <- descendant?(path, workspace),
         true <- safe_components?(root, path),
         {:ok, stat} <- File.lstat(path),
         :regular <- stat.type,
         true <- stat.size in 1..1_048_576,
         true <- (stat.mode &&& 0o077) == 0,
         {:ok, root_stat} <- File.stat(root),
         true <- stat.uid == root_stat.uid do
      :ok
    else
      _invalid -> :error
    end
  end

  defp valid_workspace?(path) when is_binary(path) do
    Path.type(path) == :absolute and Path.expand(path) == path and
      match?({:ok, %File.Stat{type: :directory}}, File.lstat(path))
  end

  defp valid_workspace?(_path), do: false

  defp safe_components?(root, path) do
    relative = Path.relative_to(path, root)

    relative
    |> Path.split()
    |> Enum.drop(-1)
    |> Enum.reduce_while(root, fn component, parent ->
      candidate = Path.join(parent, component)

      case File.lstat(candidate) do
        {:ok, %File.Stat{type: :directory}} -> {:cont, candidate}
        _invalid -> {:halt, false}
      end
    end)
    |> is_binary()
  end

  defp descendant?(path, root) when is_binary(path) and is_binary(root) do
    relative = Path.relative_to(Path.expand(path), Path.expand(root))

    Path.type(relative) != :absolute and relative != "." and relative != ".." and
      not String.starts_with?(relative, "../")
  end

  defp current(private, current) do
    if current[:attempt_iri] == private.attempt_iri and
         current[:fencing_token] == private.fencing_token and
         current[:credential_generation] == private.credential_generation,
       do: :ok,
       else: :error
  end

  defp normalize_termination(:normal), do: :termination
  defp normalize_termination(:shutdown), do: :termination
  defp normalize_termination({:shutdown, _reason}), do: :termination
  defp normalize_termination(_reason), do: :worker_loss

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
end
