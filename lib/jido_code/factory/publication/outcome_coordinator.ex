defmodule JidoCode.Factory.Publication.OutcomeCoordinator do
  @moduledoc """
  Closes publication through external observation, verification, and decision.

  Every durable fact crosses an accepted semantic command. Runtime or
  publication success is never accepted as goal satisfaction on its own.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Publication.GoalOutcome
  alias JidoCode.Factory.Publication.Result
  alias JidoCode.Knowledge

  @dispositions ~w[accept reject defer waive supersede request_more]a

  @spec decide(Result.t(), map(), module(), term(), module(), term(), keyword()) ::
          {:ok, GoalOutcome.t()} | {:error, AdapterError.t()}
  def decide(
        publication,
        decision_input,
        observer,
        observer_state,
        verifier,
        verifier_state,
        options \\ []
      )

  def decide(
        %Result{} = publication,
        decision_input,
        observer,
        observer_state,
        verifier,
        verifier_state,
        options
      )
      when is_map(decision_input) and is_atom(observer) and is_atom(verifier) and
             is_list(options) do
    with true <- observer?(observer),
         true <- verifier?(verifier),
         {:ok, observation} <- observer.observe(observer_state, publication, options),
         :ok <- observation(observation, publication),
         {:ok, observation_receipt} <- commit(observation.observation_command, options),
         {:ok, verification} <-
           verifier.verify(verifier_state, publication, observation, options),
         :ok <- verification(verification, publication, observation),
         {:ok, evidence_receipt} <- commit(verification.evidence_command, options),
         {:ok, decision} <-
           build_decision(publication, observation, verification, decision_input, options),
         :ok <- decision(decision, observation, verification),
         {:ok, decision_receipt} <- commit(decision.decision_command, options) do
      {:ok,
       %GoalOutcome{
         publication_attempt_iri: publication.attempt_iri,
         external_revision: observation.external_revision,
         confirmation_iri: observation.confirmation_iri,
         post_change_snapshot_iri: verification.post_change_snapshot_iri,
         evidence_iris: verification.evidence_iris,
         disposition: decision.disposition,
         observation_receipt: observation_receipt,
         evidence_receipt: evidence_receipt,
         decision_receipt: decision_receipt,
         goal_satisfied?: decision.disposition in [:accept, :waive],
         terminal?: true
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:publication_goal_outcome)
    end
  rescue
    _error -> unavailable(:publication_goal_outcome)
  catch
    :exit, _reason -> unavailable(:publication_goal_outcome)
  end

  def decide(
        _publication,
        _input,
        _observer,
        _observer_state,
        _verifier,
        _verifier_state,
        _options
      ),
      do: invalid(:publication_goal_outcome)

  defp observation(
         %{
           publication_attempt_iri: attempt_iri,
           external_pull_request_id: pull_request_id,
           external_revision: external_revision,
           provider_event_id: provider_event_id,
           confirmation_iri: confirmation_iri,
           confirmation_graph_iri: confirmation_graph_iri,
           confirmation_graph_revision: confirmation_revision,
           observation_command: observation_command
         },
         publication
       ) do
    cond do
      attempt_iri != publication.attempt_iri ->
        conflict(:publication_observation_attempt)

      pull_request_id != publication.external_pull_request_id ->
        conflict(:publication_observation_pull_request)

      external_revision != publication.new_object ->
        conflict(:publication_observation_revision)

      not text?(provider_event_id, 256) ->
        invalid(:publication_observation_event)

      Knowledge.validate_resource_identity(confirmation_iri) != :ok ->
        invalid(:publication_confirmation)

      not match?(
        {:ok, family} when family in [:observation_batch, :source_revision],
        Knowledge.validate_graph_identity(confirmation_graph_iri)
      ) ->
        invalid(:publication_confirmation_graph)

      not is_integer(confirmation_revision) or confirmation_revision <= 0 ->
        invalid(:publication_confirmation_revision)

      not Knowledge.observation_command?(observation_command) ->
        invalid(:publication_observation_command)

      true ->
        :ok
    end
  end

  defp observation(_observation, _publication), do: invalid(:publication_observation)

  defp verification(
         %{
           publication_attempt_iri: attempt_iri,
           external_revision: external_revision,
           post_change_snapshot_iri: snapshot_iri,
           evaluator_iri: evaluator_iri,
           execution_actor_iri: execution_actor_iri,
           evidence_iris: evidence_iris,
           evidence_command: evidence_command
         },
         publication,
         observation
       ) do
    cond do
      attempt_iri != publication.attempt_iri ->
        conflict(:post_change_verification_attempt)

      external_revision != observation.external_revision ->
        conflict(:post_change_verification_revision)

      Knowledge.validate_resource_identity(snapshot_iri) != :ok ->
        invalid(:post_change_snapshot)

      Knowledge.validate_resource_identity(evaluator_iri) != :ok or
          Knowledge.validate_resource_identity(execution_actor_iri) != :ok ->
        invalid(:post_change_verification_actor)

      evaluator_iri == execution_actor_iri ->
        unauthorized(:post_change_verification_separation)

      resource_list(evidence_iris) != :ok ->
        invalid(:post_change_verification_evidence)

      not Knowledge.verification_evidence_command?(evidence_command) ->
        invalid(:post_change_verification_command)

      true ->
        :ok
    end
  end

  defp verification(_verification, _publication, _observation),
    do: invalid(:post_change_verification)

  defp build_decision(publication, observation, verification, decision_input, options) do
    case Keyword.get(options, :decision_builder) do
      builder when is_function(builder, 4) ->
        case builder.(publication, observation, verification, decision_input) do
          {:ok, decision} when is_map(decision) -> {:ok, decision}
          {:error, %AdapterError{} = error} -> {:error, error}
          _invalid -> invalid(:final_goal_decision_builder)
        end

      _missing ->
        invalid(:final_goal_decision_builder)
    end
  end

  defp decision(
         %{
           disposition: disposition,
           outcome_stage: :final_goal,
           actor_iri: actor_iri,
           execution_actor_iri: execution_actor_iri,
           evaluator_iri: evaluator_iri,
           evidence_iris: evidence_iris,
           confirmation_iris: confirmation_iris,
           requested_effects: [],
           decision_command: decision_command
         },
         observation,
         verification
       )
       when disposition in @dispositions do
    cond do
      actor_iri == execution_actor_iri ->
        unauthorized(:final_goal_actor_separation)

      disposition in [:accept, :waive, :supersede] and actor_iri == evaluator_iri ->
        unauthorized(:final_goal_evaluator_separation)

      execution_actor_iri != verification.execution_actor_iri or
          evaluator_iri != verification.evaluator_iri ->
        conflict(:final_goal_actor_binding)

      Enum.sort(evidence_iris) != Enum.sort(verification.evidence_iris) ->
        conflict(:final_goal_evidence_binding)

      confirmation_iris != [observation.confirmation_iri] ->
        conflict(:final_goal_confirmation_binding)

      not Knowledge.goal_outcome_command?(decision_command) ->
        invalid(:final_goal_decision_command)

      true ->
        :ok
    end
  end

  defp decision(_decision, _observation, _verification), do: invalid(:final_goal_decision)

  defp commit(command, options) do
    case Keyword.get(options, :command_executor) do
      executor when is_function(executor, 1) ->
        case executor.(command) do
          {:ok, %{outcome: outcome} = receipt} when outcome in [:committed, :already_committed] ->
            {:ok, receipt}

          {:error, %AdapterError{} = error} ->
            {:error, error}

          _invalid ->
            unavailable(:outcome_command_commit)
        end

      _missing ->
        invalid(:outcome_command_executor)
    end
  end

  defp observer?(module),
    do: Code.ensure_loaded?(module) and function_exported?(module, :observe, 3)

  defp verifier?(module),
    do: Code.ensure_loaded?(module) and function_exported?(module, :verify, 4)

  defp resource_list(values) when is_list(values) and values != [] and length(values) <= 100 do
    if values |> Enum.uniq() |> length() == length(values) and
         Enum.all?(values, &(Knowledge.validate_resource_identity(&1) == :ok)),
       do: :ok,
       else: :error
  end

  defp resource_list(_values), do: :error

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
