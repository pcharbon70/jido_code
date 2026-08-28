defmodule JidoCode.Product.ManagedCodingAttempt do
  @moduledoc "Browser-safe managed coding projection rebuilt from authorized graph facts."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.Redactor

  @states ~w[admitted preparing running awaiting_actor assembling_candidate candidate_ready verifying dispositioned delayed unavailable indeterminate cancelled superseded policy_blocked failed]a
  @wait_reasons [nil, :actor, :model, :tool, :capacity, :verifier, :policy]
  @verification ~w[not_started pending passed failed indeterminate unavailable timeout expired]a
  @dispositions [nil, :accepted, :rejected, :indeterminate, :expired, :superseded]
  @runtime_classes ~w[host_controlled delegated_cli]a
  @deployment_classes ~w[developer_local managed_fleet]a
  @billing_modes ~w[subscription metered organization unknown]a
  @readiness_states ~w[ready stale unavailable unknown]a
  @rollout_stages ~w[evaluation shadow pilot production disabled]a
  @interaction_states ~w[none open awaiting_actor closed]a
  @forbidden_detail_keys ~w[argv credential credentials executable graph graph_iri hidden_reasoning pid process_id prompt prompts provider_session raw_output reasoning secret secrets session transcript transcripts workspace_path]
  @internal_keys ~w[attempt_iri repository_iri task_iri profile_iri capability_iri fencing_token sequence actor_iri]a
  @enforce_keys @internal_keys ++
                  ~w[presentation_ref task_label state wait_reason budgets interactions tools checks candidate_ref verification disposition evidence_refs updated_at]a
  defstruct @enforce_keys ++
              [
                runtime_class: :host_controlled,
                profile_label: "Managed coding",
                provider: "native",
                deployment_class: :managed_fleet,
                billing_mode: :unknown,
                readiness: :unknown,
                readiness_age_seconds: nil,
                rollout_stage: :production,
                repository_envelope: "authorized repository",
                limitations: [],
                interaction_state: :none,
                workspace: %{},
                candidate: %{},
                verification_details: %{},
                disposition_details: %{},
                recovery: %{}
              ]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(graph) when is_map(graph) do
    with :ok <- resources(graph),
         fence when is_integer(fence) and fence > 0 <- graph[:fencing_token],
         sequence when is_integer(sequence) and sequence >= 0 <- graph[:sequence],
         state when state in @states <- graph[:state],
         reason when reason in @wait_reasons <- graph[:wait_reason],
         verification when verification in @verification <- graph[:verification],
         disposition when disposition in @dispositions <- graph[:disposition],
         true <- text?(graph[:task_label], 160),
         {:ok, budgets} <- safe_map(graph[:budgets], 32),
         {:ok, interactions} <- safe_summaries(graph[:interactions], 100),
         {:ok, tools} <- safe_summaries(graph[:tools], 100),
         {:ok, checks} <- safe_summaries(graph[:checks], 100),
         {:ok, candidate_ref} <- optional_ref(graph[:candidate_iri]),
         {:ok, evidence_refs} <- refs(graph[:evidence_iris]),
         {:ok, product} <- product_fields(graph),
         %DateTime{} = updated_at <- graph[:updated_at],
         presentation_ref <- presentation_ref(graph.attempt_iri) do
      values =
        graph
        |> Map.take(@internal_keys)
        |> Map.merge(%{
          presentation_ref: presentation_ref,
          task_label: graph.task_label,
          state: state,
          wait_reason: reason,
          budgets: budgets,
          interactions: interactions,
          tools: tools,
          checks: checks,
          candidate_ref: candidate_ref,
          verification: verification,
          disposition: disposition,
          evidence_refs: evidence_refs,
          updated_at: DateTime.truncate(updated_at, :microsecond)
        })
        |> Map.merge(product)

      {:ok, struct!(__MODULE__, values)}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_graph), do: invalid()

  @spec view(t()) :: map()
  def view(%__MODULE__{} = attempt) do
    Map.take(attempt, [
      :presentation_ref,
      :task_label,
      :state,
      :wait_reason,
      :budgets,
      :interactions,
      :tools,
      :checks,
      :candidate_ref,
      :verification,
      :disposition,
      :evidence_refs,
      :updated_at,
      :runtime_class,
      :profile_label,
      :provider,
      :deployment_class,
      :billing_mode,
      :readiness,
      :readiness_age_seconds,
      :rollout_stage,
      :repository_envelope,
      :limitations,
      :interaction_state,
      :workspace,
      :candidate,
      :verification_details,
      :disposition_details,
      :recovery
    ])
  end

  @spec control_available?(t(), atom()) :: boolean()
  def control_available?(%__MODULE__{} = attempt, :steer),
    do: attempt.state in [:preparing, :running, :awaiting_actor]

  def control_available?(%__MODULE__{} = attempt, :answer),
    do:
      attempt.state == :awaiting_actor and attempt.wait_reason == :actor and
        attempt.interaction_state == :awaiting_actor

  def control_available?(%__MODULE__{} = attempt, :cancel),
    do:
      attempt.state in [
        :admitted,
        :preparing,
        :running,
        :awaiting_actor,
        :assembling_candidate,
        :verifying,
        :delayed,
        :indeterminate
      ]

  def control_available?(%__MODULE__{} = attempt, :handoff),
    do: attempt.state in [:running, :awaiting_actor]

  def control_available?(%__MODULE__{} = attempt, :recovery),
    do:
      attempt.state in [:failed, :indeterminate, :delayed, :unavailable] and
        recovery_accepted?(attempt.recovery)

  def control_available?(_attempt, _action), do: false

  @spec presentation_ref(String.t()) :: String.t()
  def presentation_ref(attempt_iri) do
    :crypto.hash(:sha256, "managed-coding-attempt\n" <> attempt_iri)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 32)
  end

  @spec valid_presentation_ref?(term()) :: boolean()
  def valid_presentation_ref?(value),
    do: is_binary(value) and byte_size(value) == 32 and Regex.match?(~r/^[A-Za-z0-9_-]+$/, value)

  defp resources(graph) do
    if Enum.all?(@internal_keys -- [:fencing_token, :sequence], fn field ->
         ResourceIdentity.validate(graph[field]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp safe_map(value, maximum) when is_map(value) and map_size(value) <= maximum do
    case Redactor.sanitize(value) do
      {:ok, safe, %{redacted_count: 0}} -> {:ok, safe}
      _unsafe -> :error
    end
  end

  defp safe_map(_value, _maximum), do: :error

  defp safe_summaries(values, maximum) when is_list(values) and length(values) <= maximum do
    allowed = [:kind, :label, :status]

    if Enum.all?(values, fn value ->
         is_map(value) and Enum.all?(Map.keys(value), &(&1 in allowed)) and
           text?(value[:label], 160) and is_atom(value[:kind]) and is_atom(value[:status])
       end) do
      normalized =
        Enum.map(values, fn value ->
          %{kind: to_string(value.kind), label: value.label, status: to_string(value.status)}
        end)

      case Redactor.sanitize(normalized) do
        {:ok, safe, %{redacted_count: 0}} -> {:ok, safe}
        _unsafe -> :error
      end
    else
      :error
    end
  end

  defp safe_summaries(_values, _maximum), do: :error

  defp optional_ref(nil), do: {:ok, nil}

  defp optional_ref(iri) do
    with :ok <- ResourceIdentity.validate(iri), do: {:ok, presentation_ref(iri)}
  end

  defp refs(values) when is_list(values) and length(values) <= 128 do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)),
      do: {:ok, values |> Enum.map(&presentation_ref/1) |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp refs(_values), do: :error

  defp product_fields(graph) do
    with runtime when runtime in @runtime_classes <-
           Map.get(graph, :runtime_class, :host_controlled),
         {:ok, profile_label} <-
           optional_text(Map.get(graph, :profile_label), "Managed coding", 128),
         {:ok, provider} <- provider(Map.get(graph, :provider, "native")),
         deployment when deployment in @deployment_classes <-
           Map.get(graph, :deployment_class, :managed_fleet),
         billing when billing in @billing_modes <- Map.get(graph, :billing_mode, :unknown),
         readiness when readiness in @readiness_states <- Map.get(graph, :readiness, :unknown),
         :ok <- age(Map.get(graph, :readiness_age_seconds)),
         rollout when rollout in @rollout_stages <- Map.get(graph, :rollout_stage, :production),
         {:ok, envelope} <-
           optional_text(Map.get(graph, :repository_envelope), "authorized repository", 160),
         {:ok, limitations} <- limitations(Map.get(graph, :limitations, [])),
         interaction when interaction in @interaction_states <-
           Map.get(graph, :interaction_state, inferred_interaction(graph)),
         {:ok, workspace} <- public_map(Map.get(graph, :workspace, %{}), 32),
         {:ok, candidate} <- public_map(Map.get(graph, :candidate, %{}), 32),
         {:ok, verification_details} <-
           public_map(Map.get(graph, :verification_details, %{}), 32),
         {:ok, disposition_details} <-
           public_map(Map.get(graph, :disposition_details, %{}), 32),
         {:ok, recovery} <- public_map(Map.get(graph, :recovery, %{}), 32) do
      {:ok,
       %{
         runtime_class: runtime,
         profile_label: profile_label,
         provider: provider,
         deployment_class: deployment,
         billing_mode: billing,
         readiness: readiness,
         readiness_age_seconds: Map.get(graph, :readiness_age_seconds),
         rollout_stage: rollout,
         repository_envelope: envelope,
         limitations: limitations,
         interaction_state: interaction,
         workspace: workspace,
         candidate: candidate,
         verification_details: verification_details,
         disposition_details: disposition_details,
         recovery: recovery
       }}
    else
      _invalid -> :error
    end
  end

  defp optional_text(nil, default, _maximum), do: {:ok, default}

  defp optional_text(value, _default, maximum) when is_binary(value) do
    if text?(value, maximum), do: {:ok, value}, else: :error
  end

  defp optional_text(_value, _default, _maximum), do: :error

  defp provider(value) when is_atom(value), do: provider(Atom.to_string(value))

  defp provider(value) when is_binary(value) do
    if byte_size(value) in 1..64 and Regex.match?(~r/^[a-z][a-z0-9_]*$/, value),
      do: {:ok, value},
      else: :error
  end

  defp provider(_value), do: :error

  defp age(nil), do: :ok
  defp age(value) when is_integer(value) and value >= 0, do: :ok
  defp age(_value), do: :error

  defp limitations(values) when is_list(values) and length(values) <= 32 do
    normalized = Enum.map(values, &to_string/1)

    if Enum.all?(normalized, &(byte_size(&1) in 1..160 and Redactor.reject_sensitive(&1) == :ok)),
      do: {:ok, normalized},
      else: :error
  end

  defp limitations(_values), do: :error

  defp inferred_interaction(%{state: :awaiting_actor, wait_reason: :actor}),
    do: :awaiting_actor

  defp inferred_interaction(_graph), do: :none

  defp recovery_accepted?(recovery) when is_map(recovery),
    do: Map.get(recovery, :accepted, Map.get(recovery, "accepted", false)) == true

  defp recovery_accepted?(_recovery), do: false

  defp public_map(value, maximum) do
    with {:ok, safe} <- safe_map(value, maximum),
         true <- public_detail?(safe) do
      {:ok, safe}
    else
      _unsafe -> :error
    end
  end

  defp public_detail?(value) when is_map(value) do
    Enum.all?(value, fn {key, nested} ->
      String.downcase(to_string(key)) not in @forbidden_detail_keys and public_detail?(nested)
    end)
  end

  defp public_detail?(value) when is_list(value), do: Enum.all?(value, &public_detail?/1)

  defp public_detail?(value) when is_binary(value) do
    not String.starts_with?(value, ["/", "https://jido.run/", "file:"])
  end

  defp public_detail?(value) when is_nil(value) or is_boolean(value) or is_number(value), do: true
  defp public_detail?(_value), do: false

  defp text?(value, maximum),
    do:
      is_binary(value) and byte_size(value) in 1..maximum and
        Redactor.reject_sensitive(value) == :ok

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_product_projection)}
end
