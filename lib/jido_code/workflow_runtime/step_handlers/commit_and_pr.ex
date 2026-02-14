defmodule JidoCode.WorkflowRuntime.StepHandlers.CommitAndPR do
  @moduledoc """
  Handles the `CommitAndPR` shipping step branch setup phase.

  This MVP implementation derives deterministic run branch names using
  `jidocode/<workflow>/<short-run-id>`, attempts branch setup, and returns
  structured artifacts for downstream commit/push/PR phases.
  """

  @behaviour JidoCode.Forge.StepHandler

  @branch_pattern "jidocode/<workflow>/<short-run-id>"
  @branch_prefix "jidocode"
  @workflow_segment_fallback "workflow"
  @run_segment_fallback "run"
  @max_workflow_segment_length 32
  @max_short_run_id_length 24
  @hash_suffix_length 8

  @branch_setup_error_type "workflow_commit_and_pr_branch_setup_failed"
  @branch_setup_operation "setup_run_branch"
  @branch_setup_remediation "Resolve branch creation preconditions and retry CommitAndPR shipping."
  @workspace_policy_error_type "workflow_commit_and_pr_workspace_policy_failed"
  @workspace_policy_operation "validate_workspace_cleanliness"
  @workspace_policy_stage "pre_ship_workspace_policy"
  @workspace_policy_remediation """
  Clean or discard unintended workspace changes, then retry CommitAndPR shipping.
  """
  @workspace_policy_check_id "workspace_cleanliness"
  @workspace_policy_check_name "Workspace cleanliness policy check"
  @workspace_policy_mode "clean_room"
  @required_workspace_state "clean"
  @blocked_shipping_actions ["commit", "push", "create_pr"]

  @impl true
  def execute(_sprite_client, args, opts) when is_map(args) and is_list(opts) do
    with {:ok, branch_context} <- derive_branch_context(args),
         {:ok, branch_setup} <- setup_branch(branch_context, opts),
         {:ok, workspace_policy_check} <- validate_workspace_cleanliness(args, branch_context) do
      maybe_probe_commit(branch_context, opts)

      {:ok,
       %{
         run_artifacts: %{
           branch_name: Map.fetch!(branch_context, :branch_name),
           branch_derivation: Map.fetch!(branch_context, :branch_derivation),
           policy_checks: %{
             workspace_cleanliness: workspace_policy_check
           }
         },
         branch_setup: branch_setup,
         policy_checks: %{
           workspace_cleanliness: workspace_policy_check
         },
         shipping_flow: %{
           completed_stage: "workspace_policy_check",
           next_stage: "commit_changes"
         }
       }}
    end
  end

  def execute(_sprite_client, _args, _opts) do
    {:error,
     branch_setup_error(
       "invalid_arguments",
       "CommitAndPR shipping step requires map args.",
       nil
     )}
  end

  @doc false
  @spec default_branch_setup_runner(map()) :: {:ok, map()}
  def default_branch_setup_runner(branch_context) when is_map(branch_context) do
    {:ok,
     %{
       status: "created",
       adapter: "default_noop",
       command_intent: "git checkout -b #{Map.get(branch_context, :branch_name)}"
     }}
  end

  defp derive_branch_context(args) when is_map(args) do
    workflow_name =
      args |> map_get(:workflow_name, "workflow_name") |> normalize_optional_string()

    run_id = args |> map_get(:run_id, "run_id") |> normalize_optional_string()

    cond do
      is_nil(workflow_name) ->
        {:error,
         branch_setup_error(
           "workflow_name_missing",
           "CommitAndPR branch derivation requires workflow_name metadata.",
           nil
         )}

      is_nil(run_id) ->
        {:error,
         branch_setup_error(
           "run_id_missing",
           "CommitAndPR branch derivation requires run_id metadata.",
           nil
         )}

      true ->
        {workflow_segment, workflow_segment_strategy} =
          normalize_branch_segment(
            workflow_name,
            @workflow_segment_fallback,
            @max_workflow_segment_length
          )

        {short_run_id, short_run_id_strategy} =
          normalize_branch_segment(run_id, @run_segment_fallback, @max_short_run_id_length)

        branch_name = "#{@branch_prefix}/#{workflow_segment}/#{short_run_id}"

        {:ok,
         %{
           branch_name: branch_name,
           branch_derivation: %{
             pattern: @branch_pattern,
             workflow_name: workflow_name,
             workflow_segment: workflow_segment,
             workflow_segment_strategy: workflow_segment_strategy,
             run_id: run_id,
             short_run_id: short_run_id,
             short_run_id_strategy: short_run_id_strategy
           }
         }}
    end
  end

  defp derive_branch_context(_args) do
    {:error,
     branch_setup_error(
       "invalid_arguments",
       "CommitAndPR branch derivation requires map args.",
       nil
     )}
  end

  defp setup_branch(branch_context, opts) when is_map(branch_context) and is_list(opts) do
    branch_setup_runner =
      Keyword.get(opts, :branch_setup_runner, &__MODULE__.default_branch_setup_runner/1)

    if is_function(branch_setup_runner, 1) do
      safe_invoke_branch_setup_runner(branch_setup_runner, branch_context)
    else
      {:error,
       branch_setup_error(
         "branch_setup_runner_invalid",
         "CommitAndPR branch setup runner configuration is invalid.",
         branch_context
       )}
    end
  end

  defp setup_branch(branch_context, _opts) do
    {:error,
     branch_setup_error(
       "branch_setup_runner_invalid",
       "CommitAndPR branch setup runner configuration is invalid.",
       branch_context
     )}
  end

  defp safe_invoke_branch_setup_runner(branch_setup_runner, branch_context)
       when is_function(branch_setup_runner, 1) and is_map(branch_context) do
    try do
      case branch_setup_runner.(branch_context) do
        :ok ->
          {:ok, %{status: "created"}}

        {:ok, result} when is_map(result) ->
          {:ok, result}

        {:ok, result} ->
          {:ok, %{status: "created", detail: "Branch setup runner returned #{inspect(result)}."}}

        {:error, reason} ->
          {:error,
           branch_setup_error(
             "branch_setup_failed",
             "Run branch creation failed and shipping halted before commit.",
             branch_context,
             reason
           )}

        other ->
          {:error,
           branch_setup_error(
             "branch_setup_invalid_result",
             "Branch setup runner returned an invalid result (#{inspect(other)}).",
             branch_context
           )}
      end
    rescue
      exception ->
        {:error,
         branch_setup_error(
           "branch_setup_runner_crashed",
           "Branch setup runner crashed (#{Exception.message(exception)}).",
           branch_context
         )}
    catch
      kind, reason ->
        {:error,
         branch_setup_error(
           "branch_setup_runner_threw",
           "Branch setup runner threw #{inspect({kind, reason})}.",
           branch_context
         )}
    end
  end

  defp validate_workspace_cleanliness(args, branch_context)
       when is_map(args) and is_map(branch_context) do
    workspace_policy_check = build_workspace_policy_check(args, branch_context)

    if workspace_policy_check.status == "passed" do
      {:ok, workspace_policy_check}
    else
      {:error,
       workspace_policy_error(
         workspace_policy_reason_type(workspace_policy_check),
         Map.get(workspace_policy_check, :detail, "Workspace cleanliness policy blocked shipping."),
         branch_context,
         workspace_policy_check
       )}
    end
  end

  defp validate_workspace_cleanliness(_args, branch_context) do
    fallback_policy_check =
      %{
        id: @workspace_policy_check_id,
        name: @workspace_policy_check_name,
        status: "failed",
        policy_mode: @workspace_policy_mode,
        required_state: @required_workspace_state,
        observed_state: "unknown",
        environment_mode: "cloud",
        detail: "Workspace cleanliness state is unavailable and shipping is blocked.",
        remediation: @workspace_policy_remediation,
        run_metadata: %{},
        step_metadata: default_step_metadata(),
        checked_at: timestamp_now()
      }

    {:error,
     workspace_policy_error(
       "workspace_state_unknown",
       "Workspace cleanliness state is unavailable and shipping is blocked.",
       branch_context,
       fallback_policy_check
     )}
  end

  defp maybe_probe_commit(branch_context, opts) when is_map(branch_context) and is_list(opts) do
    case Keyword.get(opts, :commit_probe) do
      commit_probe when is_function(commit_probe, 1) ->
        commit_probe.(branch_context)
        :ok

      _other ->
        :ok
    end
  rescue
    _exception -> :ok
  end

  defp maybe_probe_commit(_branch_context, _opts), do: :ok

  defp normalize_branch_segment(value, fallback, max_length)
       when is_integer(max_length) and max_length > 0 do
    normalized_segment = normalize_branch_slug(value, fallback)

    if String.length(normalized_segment) <= max_length do
      {normalized_segment, "slug"}
    else
      {truncate_with_hash_suffix(normalized_segment, max_length), "slug_with_hash_suffix"}
    end
  end

  defp normalize_branch_slug(value, fallback) do
    value
    |> normalize_optional_string()
    |> case do
      nil ->
        fallback

      normalized_value ->
        normalized_value
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9]+/, "-")
        |> String.replace(~r/-+/, "-")
        |> String.trim("-")
        |> case do
          "" -> fallback
          segment -> segment
        end
    end
  end

  defp truncate_with_hash_suffix(segment, max_length)
       when is_binary(segment) and is_integer(max_length) and max_length > @hash_suffix_length + 1 do
    hash_suffix = segment_fingerprint(segment)
    prefix_length = max_length - @hash_suffix_length - 1
    prefix = segment |> String.slice(0, prefix_length) |> String.trim_trailing("-")

    case prefix do
      "" -> String.slice(hash_suffix, 0, max_length)
      normalized_prefix -> "#{normalized_prefix}-#{hash_suffix}"
    end
  end

  defp truncate_with_hash_suffix(segment, max_length)
       when is_binary(segment) and is_integer(max_length) and max_length > 0 do
    segment
    |> segment_fingerprint()
    |> String.slice(0, max_length)
  end

  defp segment_fingerprint(segment) when is_binary(segment) do
    segment
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> String.slice(0, @hash_suffix_length)
  end

  defp build_workspace_policy_check(args, branch_context)
       when is_map(args) and is_map(branch_context) do
    environment_mode = environment_mode_from_args(args)
    observed_state = workspace_state_from_args(args)
    status = workspace_policy_status(observed_state)
    branch_derivation = branch_context |> map_get(:branch_derivation, "branch_derivation") |> normalize_map()

    %{
      id: @workspace_policy_check_id,
      name: @workspace_policy_check_name,
      status: status,
      policy_mode: @workspace_policy_mode,
      required_state: @required_workspace_state,
      observed_state: observed_state,
      environment_mode: environment_mode,
      detail: workspace_policy_detail(status, environment_mode, observed_state),
      remediation: workspace_policy_remediation(status),
      run_metadata: %{
        workflow_name: branch_derivation |> map_get(:workflow_name, "workflow_name") |> normalize_optional_string(),
        run_id: branch_derivation |> map_get(:run_id, "run_id") |> normalize_optional_string(),
        branch_name: branch_context |> map_get(:branch_name, "branch_name") |> normalize_optional_string(),
        environment_mode: environment_mode
      },
      step_metadata: default_step_metadata(),
      checked_at: timestamp_now()
    }
  end

  defp workspace_policy_status("clean"), do: "passed"
  defp workspace_policy_status(_observed_state), do: "failed"

  defp workspace_policy_detail("passed", environment_mode, "clean") do
    "Workspace is clean and satisfies #{environment_mode} clean-room shipping policy."
  end

  defp workspace_policy_detail("failed", environment_mode, "dirty") do
    "#{String.capitalize(environment_mode)} mode requires a clean workspace before commit, push, and PR."
  end

  defp workspace_policy_detail("failed", environment_mode, _observed_state) do
    "#{String.capitalize(environment_mode)} mode requires a clean workspace, but workspace cleanliness was unknown."
  end

  defp workspace_policy_remediation("passed"), do: "Workspace meets clean-room shipping requirements."
  defp workspace_policy_remediation(_status), do: @workspace_policy_remediation

  defp workspace_policy_reason_type(%{observed_state: "dirty"}), do: "workspace_dirty"
  defp workspace_policy_reason_type(%{observed_state: "unknown"}), do: "workspace_state_unknown"
  defp workspace_policy_reason_type(_workspace_policy_check), do: "workspace_policy_failed"

  defp environment_mode_from_args(args) when is_map(args) do
    args
    |> map_get(
      :environment_mode,
      "environment_mode",
      map_get(args, :workspace_mode, "workspace_mode", map_get(args, :mode, "mode", "cloud"))
    )
    |> normalize_environment_mode()
  end

  defp environment_mode_from_args(_args), do: "cloud"

  defp workspace_state_from_args(args) when is_map(args) do
    explicit_state =
      args
      |> map_get(:workspace_state, "workspace_state")
      |> normalize_workspace_state()

    status_state =
      args
      |> map_get(:workspace_status, "workspace_status")
      |> normalize_workspace_state()

    clean_flag_state =
      args
      |> map_get(
        :workspace_clean,
        "workspace_clean",
        map_get(args, :workspace_is_clean, "workspace_is_clean")
      )
      |> normalize_workspace_clean_flag()

    explicit_state || status_state || clean_flag_state || "unknown"
  end

  defp workspace_state_from_args(_args), do: "unknown"

  defp normalize_environment_mode(value) do
    value
    |> normalize_optional_string()
    |> case do
      nil ->
        "cloud"

      normalized_mode ->
        case String.downcase(normalized_mode) do
          "local" -> "local"
          "cloud" -> "cloud"
          "sprite" -> "cloud"
          _other -> "cloud"
        end
    end
  end

  defp normalize_workspace_state(value) when is_boolean(value),
    do: normalize_workspace_clean_flag(value)

  defp normalize_workspace_state(value) do
    value
    |> normalize_optional_string()
    |> case do
      nil ->
        nil

      normalized_state ->
        case String.downcase(normalized_state) do
          "clean" -> "clean"
          "ready" -> "clean"
          "pristine" -> "clean"
          "dirty" -> "dirty"
          "modified" -> "dirty"
          "changes" -> "dirty"
          "changes_present" -> "dirty"
          _other -> nil
        end
    end
  end

  defp normalize_workspace_clean_flag(true), do: "clean"
  defp normalize_workspace_clean_flag(false), do: "dirty"

  defp normalize_workspace_clean_flag(value) do
    value
    |> normalize_optional_string()
    |> case do
      nil ->
        nil

      normalized_value ->
        case String.downcase(normalized_value) do
          "true" -> "clean"
          "false" -> "dirty"
          "1" -> "clean"
          "0" -> "dirty"
          _other -> nil
        end
    end
  end

  defp default_step_metadata do
    %{
      step: "CommitAndPR",
      stage: @workspace_policy_stage,
      operation: @workspace_policy_operation
    }
  end

  defp branch_setup_error(reason_type, detail, branch_context, reason \\ nil) do
    %{
      error_type: @branch_setup_error_type,
      operation: @branch_setup_operation,
      reason_type: normalize_reason_type(reason_type),
      detail: format_failure_detail(detail, reason),
      remediation: @branch_setup_remediation,
      blocked_stage: "commit_changes",
      halted_before_commit: true,
      branch_name: branch_context |> map_get(:branch_name, "branch_name") |> normalize_optional_string(),
      branch_derivation: branch_context |> map_get(:branch_derivation, "branch_derivation") |> normalize_map(),
      timestamp: timestamp_now()
    }
  end

  defp workspace_policy_error(reason_type, detail, branch_context, workspace_policy_check, reason \\ nil) do
    %{
      error_type: @workspace_policy_error_type,
      operation: @workspace_policy_operation,
      reason_type: normalize_reason_type(reason_type),
      detail: format_failure_detail(detail, reason),
      remediation:
        workspace_policy_check
        |> map_get(:remediation, "remediation", @workspace_policy_remediation)
        |> normalize_optional_string() || @workspace_policy_remediation,
      blocked_stage: "commit_changes",
      blocked_actions: @blocked_shipping_actions,
      halted_before_commit: true,
      halted_before_push: true,
      halted_before_pr: true,
      branch_name: branch_context |> map_get(:branch_name, "branch_name") |> normalize_optional_string(),
      branch_derivation: branch_context |> map_get(:branch_derivation, "branch_derivation") |> normalize_map(),
      policy_check: normalize_map(workspace_policy_check),
      timestamp: timestamp_now()
    }
  end

  defp timestamp_now do
    DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
  end

  defp format_failure_detail(detail, nil), do: detail
  defp format_failure_detail(detail, ""), do: detail

  defp format_failure_detail(detail, reason) do
    "#{detail} (#{format_failure_reason(reason)})"
  end

  defp format_failure_reason(reason) when is_binary(reason), do: reason

  defp format_failure_reason(reason) do
    reason
    |> Exception.message()
    |> normalize_optional_string()
    |> case do
      nil -> inspect(reason)
      message -> message
    end
  rescue
    _exception -> inspect(reason)
  end

  defp normalize_reason_type(reason_type) do
    reason_type
    |> normalize_optional_string()
    |> case do
      nil -> "unknown"
      value -> String.replace(value, ~r/[^a-zA-Z0-9._-]/, "_")
    end
  end

  defp normalize_optional_string(nil), do: nil
  defp normalize_optional_string(value) when is_boolean(value), do: nil

  defp normalize_optional_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      normalized_value -> normalized_value
    end
  end

  defp normalize_optional_string(value) when is_atom(value),
    do: value |> Atom.to_string() |> normalize_optional_string()

  defp normalize_optional_string(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_optional_string(value) when is_float(value), do: :erlang.float_to_binary(value)
  defp normalize_optional_string(_value), do: nil

  defp normalize_map(%{} = map), do: map
  defp normalize_map(_value), do: %{}

  defp map_get(map, atom_key, string_key, default \\ nil)

  defp map_get(map, atom_key, string_key, default) when is_map(map) do
    cond do
      Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      true -> default
    end
  end

  defp map_get(_map, _atom_key, _string_key, default), do: default
end
