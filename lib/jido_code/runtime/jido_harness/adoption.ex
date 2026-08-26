defmodule JidoCode.Runtime.JidoHarness.Adoption do
  @moduledoc """
  Closed admission contract for the reviewed JidoHarness source.

  The upstream built-in finite-run adapters are deliberately not admitted:
  their prompts are currently placed in process arguments and their journal
  and tool-profile contracts do not meet JidoCode's delegated-runtime gate.
  JidoCode uses only the structured process API behind the profiles below.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Runtime.JidoHarness.CodexRelease

  @source_url "https://github.com/agentjido/jido_harness"
  @revision "e41fc1651282469f2db4219a48d9f7feef1b0dbc"
  @archive_sha256 "fbe4d49edf2e5ae7843231e45c47158a15fdcdbc494b40a3d766967c1b81f8b3"
  @upstream_version "2.0.0"
  @toolchain %{elixir: "1.19.5", otp: "28.3.1"}
  @built_in_adapters ~w[amp claude codex gemini grok kimi opencode pi zai]a
  @enabled_profiles ~w[pi_rpc_deny_all pi_rpc_read_only]a
  @registered_profiles @enabled_profiles ++ [:codex_dga1]
  @read_only_tools ~w[read grep find ls]

  @common_argv [
    "--mode",
    "rpc",
    "--no-session",
    "--no-extensions",
    "--no-skills",
    "--no-context-files",
    "--no-approve"
  ]

  @type profile_name :: :pi_rpc_deny_all | :pi_rpc_read_only | :codex_dga1

  @spec receipt() :: map()
  def receipt do
    %{
      source_url: @source_url,
      revision: @revision,
      archive_sha256: @archive_sha256,
      upstream_version: @upstream_version,
      toolchain: @toolchain,
      dependency_state: :exact_unreleased_git_revision,
      built_in_adapters: :blocked,
      managed_fleet: :blocked,
      registered_profiles: @registered_profiles,
      enabled_profiles: @enabled_profiles,
      disabled_adapters: %{zai: :native_cancellation_unproven}
    }
  end

  @spec profile(profile_name()) :: {:ok, map()} | {:error, AdapterError.t()}
  def profile(name) when name in @enabled_profiles do
    tools = if name == :pi_rpc_deny_all, do: [], else: @read_only_tools

    profile = %{
      name: name,
      provider: :pi,
      executable: "pi",
      deployment_class: :developer_local_cli,
      explicit_opt_in: true,
      managed_eligible: false,
      prompt_transport: :stdin_jsonl,
      env_mode: :replace,
      journal: %{
        mode: :memory_only,
        isolation: :controller_owned,
        nested_propagation: :required,
        record_bytes: 65_536,
        total_bytes: 1_048_576,
        memory_bytes: 1_048_576
      },
      tool_profile: if(tools == [], do: :deny_all, else: :bounded_read_only),
      tools: tools,
      argv: @common_argv ++ tool_argv(tools),
      extensions: :disabled,
      mcp_servers: :disabled,
      additional_directories: :disabled,
      project_configuration: :disabled,
      cancellation: :outer_process_group,
      live_smoke: :consent_required
    }

    validate_profile(profile)
  end

  def profile(:codex_dga1), do: CodexRelease.runtime_profile()

  def profile(_name), do: invalid(:jido_harness_profile)

  @spec validate_profile(map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def validate_profile(%{name: :codex_dga1} = profile) do
    case CodexRelease.validate_runtime_profile(profile) do
      {:ok, validated} -> {:ok, validated}
      :error -> invalid(:jido_harness_profile)
    end
  end

  def validate_profile(profile) when is_map(profile) do
    with name when name in @enabled_profiles <- profile[:name],
         :pi <- profile[:provider],
         :developer_local_cli <- profile[:deployment_class],
         true <- profile[:explicit_opt_in] == true,
         true <- profile[:managed_eligible] == false,
         :stdin_jsonl <- profile[:prompt_transport],
         :replace <- profile[:env_mode],
         :ok <- validate_journal(profile[:journal]),
         :ok <- validate_tools(profile[:tool_profile], profile[:tools], profile[:argv]),
         true <- protected_argv?(profile[:argv]),
         :disabled <- profile[:extensions],
         :disabled <- profile[:mcp_servers],
         :disabled <- profile[:additional_directories],
         :disabled <- profile[:project_configuration],
         :outer_process_group <- profile[:cancellation],
         :consent_required <- profile[:live_smoke] do
      {:ok, profile}
    else
      _invalid -> invalid(:jido_harness_profile)
    end
  rescue
    _error -> invalid(:jido_harness_profile)
  end

  def validate_profile(_profile), do: invalid(:jido_harness_profile)

  @spec built_in_adapter_enabled?(atom()) :: false
  def built_in_adapter_enabled?(adapter) when adapter in @built_in_adapters, do: false
  def built_in_adapter_enabled?(_adapter), do: false

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec archive_sha256() :: String.t()
  def archive_sha256, do: @archive_sha256

  defp validate_journal(%{
         mode: :memory_only,
         isolation: :controller_owned,
         nested_propagation: :required,
         record_bytes: record_bytes,
         total_bytes: total_bytes,
         memory_bytes: memory_bytes
       })
       when record_bytes in 1..65_536 and total_bytes >= record_bytes and
              total_bytes <= 1_048_576 and memory_bytes >= record_bytes and
              memory_bytes <= 1_048_576,
       do: :ok

  defp validate_journal(_journal), do: :error

  defp validate_tools(:deny_all, [], argv) do
    if "--no-tools" in argv and "--tools" not in argv, do: :ok, else: :error
  end

  defp validate_tools(:bounded_read_only, @read_only_tools, argv) do
    case Enum.chunk_every(argv, 2, 1, :discard) do
      pairs -> if ["--tools", Enum.join(@read_only_tools, ",")] in pairs, do: :ok, else: :error
    end
  end

  defp validate_tools(_profile, _tools, _argv), do: :error

  defp protected_argv?(argv) when is_list(argv) do
    Enum.all?(argv, &(is_binary(&1) and byte_size(&1) in 1..256)) and
      Enum.all?(
        ["--mode", "rpc", "--no-session", "--no-extensions", "--no-skills", "--no-context-files"],
        &(&1 in argv)
      )
  end

  defp protected_argv?(_argv), do: false

  defp tool_argv([]), do: ["--no-tools"]
  defp tool_argv(tools), do: ["--tools", Enum.join(tools, ",")]

  defp invalid(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end
