defmodule JidoCode.Factory.ManagedCoding.SecurityPolicy do
  @moduledoc "Tenant, trust, sandbox, and redaction controls for hostile managed-coding inputs."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Sandbox.IsolationProfile

  @scope_fields ~w[tenant_iri repository_iri]a
  @untrusted_sources ~w[repository_instruction task_text model_output tool_output retrieved_memory dependency_hook]a
  @authority_keys ~w[adapter adapter_module capability capabilities credential environment host_policy module network policy sandbox secret tool]
  @secret_patterns [
    ~r/-----BEGIN [A-Z ]*PRIVATE KEY-----/,
    ~r/\bghp_[A-Za-z0-9]{20,}\b/,
    ~r/\bsk-[A-Za-z0-9_-]{16,}\b/,
    ~r/\bAKIA[A-Z0-9]{16}\b/
  ]
  @adversarial ~w[prompt_injection path_traversal symlink_escape fork_bomb output_flood secret_exfiltration cross_tenant forged_signal dependency_lifecycle_script]a

  @spec authorize_scope(map(), map()) :: :ok | {:error, AdapterError.t()}
  def authorize_scope(expected, reference) when is_map(expected) and is_map(reference) do
    if Enum.all?(@scope_fields, fn field ->
         is_binary(expected[field]) and expected[field] == reference[field]
       end),
       do: :ok,
       else: {:error, AdapterError.new(:unauthorized, :managed_coding_tenant_scope)}
  end

  def authorize_scope(_expected, _reference),
    do: {:error, AdapterError.new(:unauthorized, :managed_coding_tenant_scope)}

  @spec untrusted(atom(), term()) :: {:ok, map()} | {:error, AdapterError.t()}
  def untrusted(source, payload) when source in @untrusted_sources do
    if safe_data?(payload) and not authority_key?(payload) do
      {:ok, %{source: source, trust: :untrusted_data, payload: payload, authority: :host_only}}
    else
      {:error, AdapterError.new(:unauthorized, :managed_coding_untrusted_input)}
    end
  end

  def untrusted(_source, _payload),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_untrusted_input)}

  @spec isolation(IsolationProfile.t(), IsolationProfile.t()) :: :ok | {:error, AdapterError.t()}
  def isolation(%IsolationProfile{} = coding, %IsolationProfile{} = verifier) do
    if isolated?(coding) and isolated?(verifier),
      do: :ok,
      else: {:error, AdapterError.new(:unauthorized, :managed_coding_isolation)}
  end

  def isolation(_coding, _verifier),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_isolation)}

  @spec redact(term()) :: %{value: term(), digests: [String.t()], classification: atom()}
  def redact(value) do
    {redacted, digests} = redact_value(value, [])

    %{
      value: redacted,
      digests: Enum.sort(Enum.uniq(digests)),
      classification: if(digests == [], do: :public, else: :sensitive_redacted)
    }
  end

  @spec adversarial_fixture(atom()) :: {:ok, map()} | {:error, AdapterError.t()}
  def adversarial_fixture(kind) when kind in @adversarial,
    do: {:ok, %{kind: kind, expected: :deny, fail_closed: true}}

  def adversarial_fixture(_kind),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_adversarial_fixture)}

  @spec adversarial_kinds() :: [atom()]
  def adversarial_kinds, do: @adversarial

  defp isolated?(profile) do
    profile.unprivileged and profile.read_only_root and profile.copy_on_write_workspace and
      not profile.host_filesystem and not profile.docker_socket and not profile.device_access and
      not profile.ambient_credentials and profile.capabilities == [] and profile.no_new_privs and
      profile.network == :deny and profile.mounts == [:workspace, :artifact] and
      profile.limits.process_count > 0 and profile.limits.output_bytes > 0
  end

  defp safe_data?(value) do
    byte_size(:erlang.term_to_binary(value, [:deterministic])) <= 65_536 and
      not runtime_term?(value)
  rescue
    _error -> false
  end

  defp runtime_term?(value) when is_pid(value) or is_port(value) or is_reference(value), do: true
  defp runtime_term?(value) when is_function(value), do: true

  defp runtime_term?(value) when is_map(value),
    do: Enum.any?(value, fn {k, v} -> runtime_term?(k) or runtime_term?(v) end)

  defp runtime_term?(value) when is_list(value), do: Enum.any?(value, &runtime_term?/1)
  defp runtime_term?(value) when is_tuple(value), do: value |> Tuple.to_list() |> runtime_term?()
  defp runtime_term?(_value), do: false

  defp authority_key?(value) when is_map(value) do
    Enum.any?(value, fn {key, nested} ->
      String.downcase(to_string(key)) in @authority_keys or authority_key?(nested)
    end)
  rescue
    _error -> true
  end

  defp authority_key?(value) when is_list(value), do: Enum.any?(value, &authority_key?/1)
  defp authority_key?(_value), do: false

  defp redact_value(value, digests) when is_binary(value) do
    Enum.reduce(@secret_patterns, {value, digests}, fn pattern, {text, found} ->
      Regex.scan(pattern, text)
      |> List.flatten()
      |> Enum.reduce({text, found}, fn secret, {current, current_found} ->
        digest = :crypto.hash(:sha256, secret) |> Base.encode16(case: :lower)
        {String.replace(current, secret, "[REDACTED:#{digest}]"), [digest | current_found]}
      end)
    end)
  end

  defp redact_value(value, digests) when is_map(value) do
    Enum.reduce(value, {%{}, digests}, fn {key, nested}, {result, found} ->
      {redacted, next_found} = redact_value(nested, found)
      {Map.put(result, key, redacted), next_found}
    end)
  end

  defp redact_value(value, digests) when is_list(value) do
    Enum.map_reduce(value, digests, &redact_value/2)
  end

  defp redact_value(value, digests), do: {value, digests}
end
