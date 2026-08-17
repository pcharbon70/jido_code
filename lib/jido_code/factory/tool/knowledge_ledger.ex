defmodule JidoCode.Factory.Tool.KnowledgeLedger do
  @moduledoc "Accepted Knowledge-facade implementation of durable tool starts and outcomes."

  @behaviour JidoCode.Factory.Ports.ToolLedger

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Authorization
  alias JidoCode.Factory.Tool.Proposal
  alias JidoCode.Factory.Tool.Request
  alias JidoCode.Factory.Tool.Result
  alias JidoCode.Factory.Tool.StartReceipt
  alias JidoCode.Knowledge

  @derive {Inspect, only: []}
  @enforce_keys [
    :attempt,
    :attempt_resolution,
    :lease,
    :expected_effect_iri,
    :start_attributes,
    :outcome_attributes,
    :executor,
    :execute_options,
    :command_options
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(keyword()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(options) when is_list(options) do
    attributes = Map.new(options)
    executor = Map.get(attributes, :executor, &Knowledge.execute/2)

    with true <- is_map(attributes[:attempt]),
         true <- is_map(attributes[:attempt_resolution]),
         true <- is_map(attributes[:lease]),
         :ok <- Knowledge.validate_resource_identity(attributes[:expected_effect_iri]),
         true <- attributes_provider?(attributes[:start_attributes]),
         true <- attributes_provider?(attributes[:outcome_attributes]),
         true <- is_function(executor, 2),
         execute_options when is_list(execute_options) <-
           Map.get(attributes, :execute_options, []),
         command_options when is_list(command_options) <-
           Map.get(attributes, :command_options, []) do
      {:ok,
       %__MODULE__{
         attempt: attributes.attempt,
         attempt_resolution: attributes.attempt_resolution,
         lease: attributes.lease,
         expected_effect_iri: attributes.expected_effect_iri,
         start_attributes: attributes.start_attributes,
         outcome_attributes: attributes.outcome_attributes,
         executor: executor,
         execute_options: execute_options,
         command_options: command_options
       }}
    else
      _invalid -> invalid(:knowledge_tool_ledger)
    end
  rescue
    _error -> invalid(:knowledge_tool_ledger)
  end

  def new(_options), do: invalid(:knowledge_tool_ledger)

  @impl true
  def start(%__MODULE__{} = ledger, %Authorization{} = authorization, %Request{} = request) do
    with {:ok, invocation} <-
           Knowledge.tool_invocation(ledger.attempt, %{
             tool_iri: request.tool_iri,
             capability_iri: ledger.attempt.capability_iri,
             tool_version: request.tool_version,
             sequence: request.sequence,
             deadline: request.deadline,
             expected_effect: ledger.expected_effect_iri,
             input_refs: request.input_refs,
             input_digests: request.input_digests
           }),
         true <- invocation.iri == request.invocation_iri,
         {:ok, proposal} <-
           authorization.proposal
           |> Proposal.persistent_attributes()
           |> Knowledge.action_proposal(),
         {:ok, attributes} <- resolve_attributes(ledger.start_attributes, authorization),
         attributes <-
           Map.merge(attributes, %{
             fencing_token: ledger.lease.fencing_token,
             action_proposal: proposal
           }),
         {:ok, command} <-
           Knowledge.start_tool_invocation(
             invocation,
             ledger.attempt,
             ledger.attempt_resolution,
             ledger.lease,
             attributes,
             ledger.command_options
           ),
         {:ok, receipt} <- ledger.executor.(command, ledger.execute_options),
         outcome when outcome in [:committed, :idempotent] <- receipt.outcome,
         {:ok, start_receipt} <-
           StartReceipt.new(%{
             invocation_iri: invocation.iri,
             authorization_digest: authorization.decision_digest,
             outcome: outcome,
             opaque: %{invocation: invocation}
           }) do
      {:ok, start_receipt}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:tool_start_commit)
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :tool_start_commit)}
  end

  def start(_ledger, _authorization, _request), do: invalid(:tool_start_commit)

  @impl true
  def outcome(
        %__MODULE__{} = ledger,
        %StartReceipt{opaque: %{invocation: invocation}},
        %Result{} = result
      ) do
    with {:ok, attributes} <- resolve_attributes(ledger.outcome_attributes, result),
         attributes <-
           Map.merge(attributes, %{
             fencing_token: ledger.lease.fencing_token,
             status: result.status,
             exit_status: result.exit_status,
             stdout: result.stdout,
             stderr: result.stderr,
             external_output_iris: result.external_output_iris,
             usage: result.usage,
             artifact_iris: result.artifact_iris,
             redaction: result.redaction
           }),
         {:ok, command} <-
           Knowledge.record_tool_outcome(
             invocation,
             ledger.attempt,
             ledger.attempt_resolution,
             ledger.lease,
             attributes,
             ledger.command_options
           ),
         {:ok, receipt} <- ledger.executor.(command, ledger.execute_options),
         outcome when outcome in [:committed, :idempotent] <- receipt.outcome do
      {:ok, receipt}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:tool_outcome_commit)
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :tool_outcome_commit)}
  end

  def outcome(_ledger, _receipt, _result), do: invalid(:tool_outcome_commit)

  defp resolve_attributes(attributes, argument) when is_function(attributes, 1) do
    case attributes.(argument) do
      value when is_map(value) -> {:ok, value}
      _invalid -> :error
    end
  end

  defp resolve_attributes(attributes, _argument) when is_map(attributes), do: {:ok, attributes}
  defp resolve_attributes(_attributes, _argument), do: :error

  defp attributes_provider?(value), do: is_map(value) or is_function(value, 1)
  defp invalid(operation), do: {:error, AdapterError.new(:corrupt, operation)}
end
