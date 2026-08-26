defmodule JidoCode.Runtime.JidoHarness.CodexRelease do
  @moduledoc "Closed application-owned release contract for the initial Codex delegated agent."

  @jido_harness_revision "e41fc1651282469f2db4219a48d9f7feef1b0dbc"
  @jido_harness_archive_sha256 "fbe4d49edf2e5ae7843231e45c47158a15fdcdbc494b40a3d766967c1b81f8b3"
  @cli_version "0.144.6"
  @model "gpt-5.3-codex"
  @executable_sha256 "a31ae9450a26216eb1e7c53102fd42123dd675974310b0e2ca3aa4cb622a2c15"
  @adapter_key "codex_cli"
  @executable_registry_key "codex_cli"

  @output_schema %{
    "$schema" => "https://json-schema.org/draft/2020-12/schema",
    "type" => "object",
    "additionalProperties" => false,
    "required" => ["classification", "summary"],
    "properties" => %{
      "classification" => %{
        "type" => "string",
        "enum" => ["candidate", "clarification", "checkpoint", "failure"]
      },
      "summary" => %{"type" => "string", "minLength" => 1, "maxLength" => 8_192}
    }
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
        events_revision: contract_digest("codex-jsonl-0.144.6/v1"),
        session: :controller_reconstructed_turns,
        cancellation: :native_and_outer,
        candidate: contract_digest("delegated-candidate/v1")
      },
      output_schema: @output_schema,
      output_schema_digest: contract_digest(@output_schema),
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
         total_bytes: 1_048_576,
         memory_bytes: 1_048_576
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
  def digest, do: contract_digest(manifest())

  @spec profile_digest() :: String.t()
  def profile_digest, do: contract_digest(profile())

  @spec executable_sha256() :: String.t()
  def executable_sha256, do: @executable_sha256

  @spec cli_version() :: String.t()
  def cli_version, do: @cli_version

  @spec model() :: String.t()
  def model, do: @model

  @spec output_schema_digest() :: String.t()
  def output_schema_digest, do: contract_digest(@output_schema)

  defp contract_digest(value) do
    value
    |> canonical()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical(%DateTime{} = value), do: DateTime.to_iso8601(value)

  defp canonical(value) when is_map(value) do
    value
    |> Enum.map(fn {key, item} -> {to_string(key), canonical(item)} end)
    |> Enum.sort()
  end

  defp canonical(value) when is_list(value), do: Enum.map(value, &canonical/1)
  defp canonical(value) when is_atom(value), do: Atom.to_string(value)
  defp canonical(value), do: value
end
