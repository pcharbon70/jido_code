defmodule JidoCode.Factory.DelegatedTurnController do
  @moduledoc "Two-turn controller-reconstructed delegated session with no provider-session authority."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @max_turns 2
  @interactive_classes ~w[clarification checkpoint]a
  @terminal_classes ~w[candidate failure]a
  @result_classes @interactive_classes ++ @terminal_classes

  @enforce_keys [
    :attempt_iri,
    :lease_iri,
    :actor_iri,
    :fencing_token,
    :profile_digest,
    :workspace_identity,
    :total_budget,
    :state,
    :turn,
    :max_turns,
    :invocations
  ]
  defstruct @enforce_keys ++ [:current_manifest_digest, :pending_kind, :terminal_reason]

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         true <- digest?(attributes[:profile_digest]),
         true <- digest?(attributes[:workspace_identity]),
         {:ok, budget} <- budget(attributes[:total_budget]) do
      {:ok,
       %__MODULE__{
         attempt_iri: attributes.attempt_iri,
         lease_iri: attributes.lease_iri,
         actor_iri: attributes.actor_iri,
         fencing_token: fence,
         profile_digest: attributes.profile_digest,
         workspace_identity: attributes.workspace_identity,
         total_budget: budget,
         state: :ready,
         turn: 0,
         max_turns: @max_turns,
         invocations: []
       }}
    else
      _invalid -> invalid(:delegated_turn_controller)
    end
  rescue
    _error -> invalid(:delegated_turn_controller)
  end

  def new(_attributes), do: invalid(:delegated_turn_controller)

  @spec begin(t(), map()) :: {:ok, t(), map()} | {:error, AdapterError.t()}
  def begin(%__MODULE__{state: :ready, turn: 0} = controller, manifest) when is_map(manifest) do
    with :ok <- manifest_matches?(controller, manifest),
         true <- digest?(manifest[:digest]),
         invocation <- invocation(controller, 1, manifest.digest, :initial) do
      {:ok,
       %{
         controller
         | state: :running,
           turn: 1,
           current_manifest_digest: manifest.digest,
           invocations: [invocation]
       }, invocation}
    else
      _invalid -> invalid(:delegated_turn_begin)
    end
  end

  def begin(%__MODULE__{}, _manifest), do: conflict(:delegated_turn_begin)

  @spec complete(t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def complete(%__MODULE__{state: :running} = controller, result) when is_map(result) do
    with :ok <- result_matches?(controller, result),
         classification when classification in @result_classes <-
           result[:classification] do
      complete_classification(controller, classification)
    else
      _invalid -> invalid(:delegated_turn_result)
    end
  end

  def complete(%__MODULE__{}, _result), do: conflict(:delegated_turn_result)

  @spec respond(t(), atom(), map()) :: {:ok, t(), map(), map()} | {:error, AdapterError.t()}
  def respond(%__MODULE__{state: :awaiting_actor} = controller, operation, response)
      when operation in [:answer, :steer] and is_map(response) do
    with true <- controller.turn < controller.max_turns,
         :ok <- response_matches?(controller, response),
         content when is_binary(content) and byte_size(content) in 1..16_384 <-
           response[:content],
         false <- authority_language?(content),
         content_digest <- digest(content),
         manifest <- delegated_manifest(controller, operation, content, content_digest),
         invocation <- invocation(controller, controller.turn + 1, manifest.digest, operation) do
      updated = %{
        controller
        | state: :running,
          turn: controller.turn + 1,
          current_manifest_digest: manifest.digest,
          pending_kind: nil,
          invocations: controller.invocations ++ [invocation]
      }

      {:ok, updated, manifest, invocation}
    else
      _invalid -> invalid(:delegated_turn_response)
    end
  end

  def respond(%__MODULE__{}, operation, _response) when operation in [:answer, :steer],
    do: conflict(:delegated_turn_response)

  def respond(%__MODULE__{}, _operation, _response), do: invalid(:delegated_turn_response)

  @spec cancel(t(), map(), keyword()) :: {:ok, t(), map()} | {:error, AdapterError.t()}
  def cancel(%__MODULE__{state: state} = controller, cancellation, options)
      when state in [:running, :awaiting_actor] and is_map(cancellation) and is_list(options) do
    commit = Keyword.get(options, :commit)
    runtime_cancel = Keyword.get(options, :runtime_cancel)
    namespace_terminate = Keyword.get(options, :namespace_terminate)

    with :ok <- cancellation_matches?(controller, cancellation),
         true <- is_function(commit, 1),
         true <- is_function(runtime_cancel, 1),
         true <- is_function(namespace_terminate, 1),
         {:ok, commit_receipt} <- commit.(cancellation),
         true <- committed?(commit_receipt),
         {:ok, runtime_receipt} <- runtime_cancel.(cancellation),
         {:ok, namespace_receipt} <- namespace_terminate.(cancellation),
         true <- terminated?(namespace_receipt) do
      receipt = %{
        commit: commit_receipt,
        runtime: runtime_receipt,
        namespace: namespace_receipt,
        late_results: :rejected
      }

      {:ok, %{controller | state: :cancelled, pending_kind: nil, terminal_reason: :cancelled},
       receipt}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      {:error, _reason} -> unavailable(:delegated_turn_cancellation)
      _invalid -> invalid(:delegated_turn_cancellation)
    end
  rescue
    _error -> unavailable(:delegated_turn_cancellation)
  end

  def cancel(%__MODULE__{}, _cancellation, _options),
    do: conflict(:delegated_turn_cancellation)

  defp complete_classification(controller, classification)
       when classification in @interactive_classes do
    if controller.turn < controller.max_turns do
      {:ok, %{controller | state: :awaiting_actor, pending_kind: classification}}
    else
      {:ok,
       %{
         controller
         | state: :failed,
           pending_kind: nil,
           terminal_reason: :turn_exhausted
       }}
    end
  end

  defp complete_classification(controller, :candidate),
    do: {:ok, %{controller | state: :candidate_ready, terminal_reason: :candidate}}

  defp complete_classification(controller, :failure),
    do: {:ok, %{controller | state: :failed, terminal_reason: :provider_failure}}

  defp manifest_matches?(controller, manifest) do
    if manifest[:attempt_iri] == controller.attempt_iri and
         manifest[:lease_iri] == controller.lease_iri and
         manifest[:fencing_token] == controller.fencing_token and
         manifest[:profile_digest] == controller.profile_digest and
         manifest[:workspace_identity] == controller.workspace_identity do
      :ok
    else
      :error
    end
  end

  defp result_matches?(controller, result) do
    current = List.last(controller.invocations)

    if result[:attempt_iri] == controller.attempt_iri and
         result[:lease_iri] == controller.lease_iri and
         result[:fencing_token] == controller.fencing_token and
         result[:profile_digest] == controller.profile_digest and
         result[:workspace_identity] == controller.workspace_identity and
         result[:turn] == controller.turn and result[:invocation_iri] == current.iri do
      :ok
    else
      :error
    end
  end

  defp response_matches?(controller, response) do
    if response[:attempt_iri] == controller.attempt_iri and
         response[:lease_iri] == controller.lease_iri and
         response[:fencing_token] == controller.fencing_token and
         response[:actor_iri] == controller.actor_iri and
         response[:profile_digest] == controller.profile_digest and
         response[:workspace_identity] == controller.workspace_identity do
      :ok
    else
      :error
    end
  end

  defp cancellation_matches?(controller, cancellation) do
    if cancellation[:attempt_iri] == controller.attempt_iri and
         cancellation[:lease_iri] == controller.lease_iri and
         cancellation[:fencing_token] == controller.fencing_token and
         cancellation[:actor_iri] == controller.actor_iri and
         cancellation[:reason] in [:cancelled, :lease_expired, :superseded] do
      :ok
    else
      :error
    end
  end

  defp delegated_manifest(controller, operation, content, content_digest) do
    material = %{
      attempt_iri: controller.attempt_iri,
      lease_iri: controller.lease_iri,
      fencing_token: controller.fencing_token,
      profile_digest: controller.profile_digest,
      workspace_identity: controller.workspace_identity,
      predecessor_digest: controller.current_manifest_digest,
      turn: controller.turn + 1,
      operation: operation,
      content_digest: content_digest
    }

    Map.merge(material, %{
      iri: resource("context-manifest", digest(material)),
      digest: digest(material),
      content: content
    })
  end

  defp invocation(controller, turn, manifest_digest, operation) do
    material = %{
      attempt_iri: controller.attempt_iri,
      lease_iri: controller.lease_iri,
      fencing_token: controller.fencing_token,
      profile_digest: controller.profile_digest,
      workspace_identity: controller.workspace_identity,
      turn: turn,
      operation: operation,
      manifest_digest: manifest_digest,
      total_budget: controller.total_budget
    }

    Map.put(material, :iri, resource("model-invocation", digest(material)))
  end

  defp resources(attributes) do
    if Enum.all?([:attempt_iri, :lease_iri, :actor_iri], fn key ->
         Knowledge.validate_resource_identity(attributes[key]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp budget(%{run_count: 2, session_turns: 2} = budget) do
    required = [:wall_ms, :idle_ms, :output_bytes]

    if Enum.all?(required, fn key ->
         value = budget[key]
         is_integer(value) and value > 0
       end),
       do: {:ok, Map.take(budget, [:run_count, :session_turns | required])},
       else: :error
  end

  defp budget(_budget), do: :error

  defp committed?(%{outcome: outcome}) when outcome in [:committed, :idempotent], do: true
  defp committed?(_receipt), do: false

  defp terminated?(%{namespace: :terminated, descendants: :absent, within_bound: true}), do: true
  defp terminated?(_receipt), do: false

  defp authority_language?(content),
    do:
      Regex.match?(
        ~r/\b(grant|authorize|permission|capability|credential|bypass|sudo)\b/i,
        content
      )

  defp resource(kind, digest), do: "https://jido.run/id/#{kind}/#{digest}"
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
