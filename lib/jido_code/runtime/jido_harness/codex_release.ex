defmodule JidoCode.Runtime.JidoHarness.CodexRelease do
  @moduledoc "Closed application-owned release contract for the initial Codex delegated agent."

  alias JidoCode.Knowledge.Control.DelegatedAgentContract, as: Contract

  @jido_harness_revision "e41fc1651282469f2db4219a48d9f7feef1b0dbc"
  @jido_harness_archive_sha256 "fbe4d49edf2e5ae7843231e45c47158a15fdcdbc494b40a3d766967c1b81f8b3"
  @cli_version "0.144.6"
  @model "gpt-5.3-codex"
  @executable_sha256 "a31ae9450a26216eb1e7c53102fd42123dd675974310b0e2ca3aa4cb622a2c15"
  @adapter_key "codex_cli"
  @executable_registry_key "codex_cli"

  @output_schema %{
    version: "1.0.0",
    additional_properties: false,
    required: [:classification, :summary],
    classifications: [:candidate, :clarification, :checkpoint, :failure],
    summary_max_bytes: 8_192
  }

  @fixed_argv [
    "exec",
    "--json",
    "--ephemeral",
    "--ignore-user-config",
    "--ignore-rules",
    "--strict-config",
    "--model",
    @model,
    "--sandbox",
    "workspace-write"
  ]

  @spec manifest() :: map()
  def manifest do
    %{
      provider: :codex,
      adapter_key: @adapter_key,
      release_revision: 1,
      state: :accepted,
      jido_harness: %{
        revision: @jido_harness_revision,
        archive_sha256: @jido_harness_archive_sha256,
        protocol: "2.0.0/process-api/1"
      },
      cli: %{
        product: "codex-cli",
        version: @cli_version,
        model: @model,
        executable_registry_key: @executable_registry_key,
        executable_sha256: @executable_sha256
      },
      protocols: %{
        prompt_transport: :stdin,
        events: :codex_jsonl,
        events_revision: Contract.digest("codex-jsonl-0.144.6/v1"),
        session: :controller_reconstructed_turns,
        cancellation: :native_and_outer,
        candidate: Contract.digest("delegated-candidate/v1")
      },
      output_schema: @output_schema,
      output_schema_digest: Contract.digest(@output_schema),
      deployment_classes: [:developer_local],
      capability_classes: [:workspace_write_registered_checks],
      observation_completeness: :partial,
      unavailable_fields: [:hidden_reasoning, :complete_internal_tool_arguments],
      built_in_codex_adapter: :blocked
    }
  end

  @spec profile() :: map()
  def profile do
    %{
      name: :codex_dga1,
      agent_key: "codex_subscription",
      runtime_class: :delegated_cli,
      provider: :codex,
      adapter_key: @adapter_key,
      executable_registry_key: @executable_registry_key,
      deployment_class: :developer_local,
      authentication_kind: :existing_cli_session,
      billing_mode: :subscription,
      model: @model,
      cli_version: @cli_version,
      prompt_transport: :stdin,
      session_policy: :controller_reconstructed_turns,
      run_count: 2,
      session_turns: 2,
      capability_class: :workspace_write_registered_checks,
      repository_envelope: ["jido_code"],
      rollout_stage: :evaluation,
      state: :disabled,
      managed_eligible: false,
      publication: :unavailable,
      merge: :unavailable,
      output_schema_digest: manifest().output_schema_digest
    }
  end

  @spec runtime_profile() :: {:ok, map()}
  def runtime_profile do
    {:ok,
     %{
       name: :codex_dga1,
       provider: :codex,
       adapter_key: @adapter_key,
       executable_registry_key: @executable_registry_key,
       deployment_class: :developer_local,
       explicit_opt_in: true,
       managed_eligible: false,
       prompt_transport: :stdin,
       env_mode: :replace,
       argv: @fixed_argv,
       model: @model,
       cli_version: @cli_version,
       output_schema: @output_schema,
       output_schema_digest: manifest().output_schema_digest,
       session_policy: :controller_reconstructed_turns,
       run_count: 2,
       session_turns: 2,
       extensions: :disabled,
       mcp_servers: :disabled,
       skills: :disabled,
       additional_directories: :disabled,
       project_configuration: :disabled,
       web_search: :disabled,
       dangerous_bypass: :disabled,
       built_in_adapter: :blocked,
       cancellation: :native_and_outer,
       journal: %{
         mode: :memory_only,
         isolation: :controller_owned,
         record_bytes: 65_536,
         total_bytes: 1_048_576
       }
     }}
  end

  @spec validate_runtime_profile(map()) :: {:ok, map()} | :error
  def validate_runtime_profile(profile) when is_map(profile) do
    {:ok, expected} = runtime_profile()
    if profile == expected, do: {:ok, profile}, else: :error
  end

  def validate_runtime_profile(_profile), do: :error

  @spec digest() :: String.t()
  def digest, do: Contract.digest(manifest())

  @spec profile_digest() :: String.t()
  def profile_digest, do: Contract.digest(profile())

  @spec executable_sha256() :: String.t()
  def executable_sha256, do: @executable_sha256

  @spec cli_version() :: String.t()
  def cli_version, do: @cli_version

  @spec model() :: String.t()
  def model, do: @model
end
