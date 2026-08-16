defmodule JidoCode.Knowledge.Trust do
  @moduledoc """
  Information-flow trust classification for the agent harness.

  Every value carries a source class with a default integrity level, and
  every authority-bearing sink declares the integrity it accepts. The
  fundamental invariant: untrusted data may populate bounded data fields,
  but it cannot create authority, enlarge capability, choose an unapproved
  sink, declassify sensitive information, modify security policy, or enter
  durable accepted memory without independent mediation.

  Integrity is independent from confidentiality. Classification here never
  declassifies content; the accepted security contract owns classification
  labels such as Public, Internal, Confidential, and Secret Reference.
  """

  alias JidoCode.Knowledge.Error

  @type source_class ::
          :accepted_policy
          | :operator_command
          | :provider_observation
          | :repository_content
          | :model_output
          | :tool_output
          | :verifier_result
          | :authorized_decision

  @type sink_class ::
          :bounded_data_field
          | :capability_grant
          | :policy_mutation
          | :accepted_memory
          | :sink_selection
          | :declassification
          | :ontology_mutation

  @integrity %{
    accepted_policy: :trusted,
    operator_command: :trusted_intent,
    provider_observation: :untrusted,
    repository_content: :untrusted_executable,
    model_output: :untrusted_proposal,
    tool_output: :untrusted_observation,
    verifier_result: :evidence,
    authorized_decision: :authority
  }

  @authority_sinks ~w[capability_grant policy_mutation accepted_memory sink_selection declassification ontology_mutation]a

  @authority_sources ~w[authorized_decision accepted_policy]a

  @spec source_classes() :: [atom()]
  def source_classes, do: Map.keys(@integrity)

  @spec sink_classes() :: [atom()]
  def sink_classes, do: [:bounded_data_field | Enum.sort(@authority_sinks)]

  @spec integrity(source_class()) :: {:ok, atom()} | {:error, Error.t()}
  def integrity(source) when is_map_key(@integrity, source),
    do: {:ok, @integrity[source]}

  def integrity(_source), do: invalid(:trust_source_class)

  @spec validate_data_flow(source_class(), sink_class()) ::
          :ok | {:error, Error.t()}
  def validate_data_flow(source, :bounded_data_field) when is_map_key(@integrity, source),
    do: :ok

  def validate_data_flow(source, sink)
      when sink in @authority_sinks and is_map_key(@integrity, source) do
    mediation =
      case {source, sink} do
        {:authorized_decision, _sink} ->
          :ok

        {:accepted_policy, sink}
        when sink in ~w[policy_mutation ontology_mutation capability_grant]a ->
          :ok

        {:verifier_result, :accepted_memory} ->
          :mediated_adoption_required

        {_source, _sink} ->
          :denied
      end

    case mediation do
      :ok -> :ok
      :mediated_adoption_required -> {:error, Error.new(:unauthorized, :trust_mediation_required)}
      :denied -> {:error, Error.new(:unauthorized, :trust_information_flow)}
    end
  end

  def validate_data_flow(_source, _sink), do: invalid(:trust_flow_contract)

  @doc """
  Classifies runtime diagnostic vocabulary.

  Runtime diagnostics map only onto the accepted attempt lifecycle. A
  missing runtime process after restart is a diagnostic, never an invented
  terminal state such as `:crashed`; new dead-runtime recovery conditions
  require a versioned protocol change.
  """
  @spec runtime_diagnostic?(atom()) :: boolean()
  def runtime_diagnostic?(:process_missing_after_restart), do: true
  def runtime_diagnostic?(:process_unreachable), do: true
  def runtime_diagnostic?(:runtime_version_incompatible), do: true
  def runtime_diagnostic?(_other), do: false

  @spec attempt_terminal_state?(atom()) :: boolean()
  def attempt_terminal_state?(state),
    do: state in ~w[completed failed timed_out abandoned cancelled superseded]a

  @spec injection_resistant_text?(term()) :: boolean()
  def injection_resistant_text?(value) when is_binary(value) do
    byte_size(value) <= 1_024 and not secret?(value)
  end

  def injection_resistant_text?(_value), do: false

  defp secret?(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
