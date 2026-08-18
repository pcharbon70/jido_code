defmodule JidoCode.Factory.Verification.FreshCheckout do
  @moduledoc """
  Independently reconstructs and checks a candidate in disposable workspaces.

  Workspace adapters return only bounded digests and statuses. The verifier
  turns those observations into the accepted `RecordVerificationEvidence`
  command, while deliberately exposing no goal transition or acceptance API.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Verification.Admission
  alias JidoCode.Factory.Verification.Evidence
  alias JidoCode.Factory.Verification.Policy
  alias JidoCode.Knowledge

  @statuses ~w[passed failed skipped timeout]a
  @digest ~r/^[a-f0-9]{64}$/
  @contract_version "1.0.0"

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec verify(Admission.t(), Policy.t(), module(), term(), keyword()) ::
          {:ok, Evidence.t()} | {:error, AdapterError.t()}
  def verify(admission, policy, adapter, adapter_state, options \\ [])

  def verify(
        %Admission{completeness: :complete} = admission,
        %Policy{} = policy,
        adapter,
        adapter_state,
        options
      )
      when is_atom(adapter) and is_list(options) do
    with true <- workspace_adapter?(adapter),
         true <- admission.evaluator_capability_iri == policy.evaluator_capability_iri,
         true <- admission.policy_revision == policy.revision,
         {:ok, base} <- adapter.checkout(adapter_state, admission, options) do
      materialize_and_verify(admission, policy, adapter, adapter_state, base, options)
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:fresh_checkout_verification)
    end
  rescue
    _error -> invalid(:fresh_checkout_verification)
  end

  def verify(%Admission{}, %Policy{}, _adapter, _adapter_state, _options),
    do: invalid(:fresh_checkout_requires_complete_run)

  def verify(_admission, _policy, _adapter, _adapter_state, _options),
    do: invalid(:fresh_checkout_verification)

  defp materialize_and_verify(admission, policy, adapter, adapter_state, base, options) do
    with :ok <- checkout_receipt(base, admission),
         :ok <- patch_size(admission, policy),
         {:ok, candidate} <-
           adapter.apply_candidate(
             adapter_state,
             base,
             admission.candidate_artifacts,
             admission.patch_digest,
             options
           ) do
      result =
        verify_candidate(admission, policy, adapter, adapter_state, base, candidate, options)

      cleanup = adapter.cleanup(adapter_state, [base, candidate], options)
      finish(result, cleanup)
    else
      {:error, %AdapterError{} = error} ->
        finish({:error, error}, adapter.cleanup(adapter_state, [base], options))
    end
  end

  defp verify_candidate(admission, policy, adapter, adapter_state, base, candidate, options) do
    with :ok <- candidate_receipt(candidate, admission),
         {:ok, changed_paths} <- adapter.changed_paths(adapter_state, candidate, options),
         :ok <- Policy.authorize_paths(policy, changed_paths),
         {:ok, checks} <-
           run_checks(policy, adapter, adapter_state, base, candidate, admission, options),
         findings <- findings(checks),
         report <- report(admission, base, candidate, changed_paths, checks, findings),
         {:ok, command} <- evidence_command(report, options) do
      {:ok,
       %Evidence{
         admission_digest: admission.input_digest,
         environment_digest: admission.verification_environment_digest,
         base_workspace_digest: base.workspace_digest,
         candidate_workspace_digest: candidate.workspace_digest,
         checks: checks,
         findings: findings,
         evidence_command: command,
         acceptance_authority?: false,
         transition_authority?: false
       }}
    end
  end

  defp run_checks(policy, adapter, adapter_state, base, candidate, admission, options) do
    Enum.reduce_while(policy.checks, {:ok, []}, fn check, {:ok, acc} ->
      case run_check(check, policy, adapter, adapter_state, base, candidate, admission, options) do
        {:ok, result} -> {:cont, {:ok, [result | acc]}}
        {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, checks} -> {:ok, Enum.reverse(checks)}
      error -> error
    end
  end

  defp run_check(
         %{owner: :candidate} = check,
         policy,
         adapter,
         adapter_state,
         base,
         candidate,
         admission,
         options
       ) do
    with {:ok, base_attempts} <-
           run_with_flake(adapter, adapter_state, base, check, policy, admission, options),
         {:ok, candidate_attempts} <-
           run_with_flake(adapter, adapter_state, candidate, check, policy, admission, options) do
      base_status = base_attempts |> List.last() |> Map.fetch!(:status)
      candidate_status = candidate_attempts |> List.last() |> Map.fetch!(:status)

      {:ok,
       Map.merge(check, %{
         status: candidate_status,
         attempts: candidate_attempts,
         base_attempts: base_attempts,
         accepted_as_evidence?: base_status == :failed and candidate_status == :passed,
         independent?: false
       })}
    end
  end

  defp run_check(check, policy, adapter, adapter_state, _base, candidate, admission, options) do
    with {:ok, attempts} <-
           run_with_flake(adapter, adapter_state, candidate, check, policy, admission, options) do
      {:ok,
       Map.merge(check, %{
         status: attempts |> List.last() |> Map.fetch!(:status),
         attempts: attempts,
         base_attempts: [],
         accepted_as_evidence?: true,
         independent?: true
       })}
    end
  end

  defp run_with_flake(adapter, adapter_state, workspace, check, policy, admission, options) do
    do_run(adapter, adapter_state, workspace, check, policy, admission, options, [], 0)
  end

  defp do_run(
         adapter,
         adapter_state,
         workspace,
         check,
         policy,
         admission,
         options,
         attempts,
         reruns
       ) do
    with {:ok, receipt} <- adapter.run_check(adapter_state, workspace, check, options),
         {:ok, normalized} <- check_receipt(receipt, workspace, check, admission) do
      attempts = attempts ++ [normalized]

      if normalized.status in policy.flake_policy.eligible_statuses and
           reruns < policy.flake_policy.max_reruns do
        do_run(
          adapter,
          adapter_state,
          workspace,
          check,
          policy,
          admission,
          options,
          attempts,
          reruns + 1
        )
      else
        {:ok, attempts}
      end
    end
  end

  defp checkout_receipt(%{base_commit: commit, workspace_digest: digest}, admission) do
    if commit == admission.base_commit and valid_digest?(digest),
      do: :ok,
      else: invalid(:verification_checkout_receipt)
  end

  defp checkout_receipt(_receipt, _admission), do: invalid(:verification_checkout_receipt)

  defp candidate_receipt(
         %{
           patch_digest: patch_digest,
           applied_artifact_digests: applied,
           workspace_digest: workspace_digest,
           complete?: true,
           executor_state_used?: false
         },
         admission
       ) do
    expected = admission.candidate_artifacts |> Enum.map(& &1.digest) |> Enum.sort()

    if patch_digest == admission.patch_digest and Enum.sort(applied) == expected and
         length(Enum.uniq(applied)) == length(applied) and valid_digest?(workspace_digest),
       do: :ok,
       else: invalid(:verification_candidate_receipt)
  end

  defp candidate_receipt(_receipt, _admission), do: invalid(:verification_candidate_receipt)

  defp check_receipt(
         %{
           check_id: id,
           status: status,
           environment_digest: environment_digest,
           command_digest: command_digest,
           result_digest: result_digest,
           output_digest: output_digest,
           workspace_digest: workspace_digest
         },
         workspace,
         check,
         admission
       ) do
    if id == check.id and status in @statuses and command_digest == check.command_digest and
         environment_digest == admission.verification_environment_digest and
         workspace_digest == workspace.workspace_digest and valid_digest?(result_digest) and
         valid_digest?(output_digest) do
      {:ok,
       %{
         status: status,
         command_digest: command_digest,
         result_digest: result_digest,
         output_digest: output_digest,
         workspace_digest: workspace_digest,
         environment_digest: environment_digest
       }}
    else
      invalid(:verification_check_receipt)
    end
  end

  defp check_receipt(_receipt, _workspace, _check, _admission),
    do: invalid(:verification_check_receipt)

  defp patch_size(admission, policy) do
    bytes = Enum.reduce(admission.candidate_artifacts, 0, &(&1.byte_count + &2))
    if bytes <= policy.max_patch_bytes, do: :ok, else: unauthorized(:verification_patch_size)
  end

  defp findings(checks) do
    checks
    |> Enum.flat_map(fn check ->
      cond do
        check.owner == :candidate and not check.accepted_as_evidence? ->
          [
            %{
              check_id: check.id,
              kind: :candidate_test_not_independent_evidence,
              severity: :warning
            }
          ]

        check.mandatory? and check.status != :passed ->
          [%{check_id: check.id, kind: :mandatory_check_failed, severity: :error}]

        true ->
          []
      end
    end)
    |> Enum.sort_by(&{&1.severity, &1.check_id})
  end

  defp report(admission, base, candidate, changed_paths, checks, findings) do
    %{
      admission_digest: admission.input_digest,
      attempt_iri: admission.attempt_iri,
      run_graph_iri: admission.run_graph_iri,
      source_graph_revisions: admission.source_graph_revisions,
      control_graph_revision: admission.control_graph_revision,
      environment_digest: admission.verification_environment_digest,
      base_commit: admission.base_commit,
      patch_digest: admission.patch_digest,
      base_workspace_digest: base.workspace_digest,
      candidate_workspace_digest: candidate.workspace_digest,
      changed_paths: Enum.sort(changed_paths),
      checks: checks,
      findings: findings,
      acceptance_authority?: false,
      transition_authority?: false
    }
  end

  defp evidence_command(report, options) do
    case Keyword.get(options, :evidence_command) do
      builder when is_function(builder, 1) ->
        case builder.(report) do
          {:ok, command} when not is_nil(command) ->
            if Knowledge.verification_evidence_command?(command),
              do: {:ok, command},
              else: invalid(:verification_evidence_command)

          _invalid ->
            invalid(:verification_evidence_command)
        end

      _missing ->
        invalid(:verification_evidence_command)
    end
  end

  defp finish({:ok, %Evidence{} = evidence}, :ok), do: {:ok, evidence}
  defp finish({:error, %AdapterError{} = error}, :ok), do: {:error, error}

  defp finish(_result, {:error, %AdapterError{} = error}),
    do: {:error, %{error | operation: :verification_workspace_cleanup}}

  defp finish(_result, _cleanup), do: invalid(:verification_workspace_cleanup)

  defp workspace_adapter?(adapter) do
    Code.ensure_loaded?(adapter) and
      Enum.all?(
        [checkout: 3, apply_candidate: 5, changed_paths: 3, run_check: 4, cleanup: 3],
        fn {function, arity} -> function_exported?(adapter, function, arity) end
      )
  end

  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end
