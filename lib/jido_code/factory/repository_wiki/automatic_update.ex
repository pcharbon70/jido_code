defmodule JidoCode.Factory.RepositoryWiki.AutomaticUpdate do
  @moduledoc "Exact-fence automatic deterministic wiki update pipeline."

  alias JidoCode.Knowledge

  @transient [:unavailable, :timeout, :persistence_failure]
  @required_ports [:reclassify, :compile, :lint, :render, :account, :activate, :mark_stale]

  @spec run(map(), map(), map()) :: {:ok, map()} | {:skipped, map()} | {:error, map()}
  def run(trigger, context, ports)
      when is_map(trigger) and is_map(context) and is_map(ports) do
    with :ok <- validate(trigger, context, ports),
         {:ok, classification} <- ports.reclassify.(trigger, context),
         {:continue, classification} <- classify(classification),
         {:ok, compilation} <- ports.compile.(trigger, classification, context),
         :ok <- exact_compilation(compilation, trigger, context),
         {:ok, lint} <- ports.lint.(compilation, context),
         :ok <- passing(lint, :lint),
         {:ok, render} <- ports.render.(compilation, context),
         :ok <- passing(render, :render),
         {:ok, usage} <- ports.account.(compilation, context),
         :ok <- zero_usage(usage),
         :ok <- current_fences(trigger, context),
         {:ok, activation} <- ports.activate.(compilation, lint, render, usage, context) do
      {:ok,
       %{
         state: :activated,
         trigger_iri: trigger.iri,
         source_fence: trigger.source_fence,
         classification: classification,
         compilation: compilation,
         lint: lint,
         render: render,
         usage: usage,
         activation: activation
       }}
    else
      {:skip, reason} ->
        {:skipped, terminal(trigger, :skipped, reason)}

      {:error, reason} ->
        _ = ports[:mark_stale] && ports.mark_stale.(trigger, reason, context)
        {:error, terminal(trigger, :failed, reason)}

      _invalid ->
        _ = ports[:mark_stale] && ports.mark_stale.(trigger, :invalid, context)
        {:error, terminal(trigger, :failed, :invalid)}
    end
  rescue
    _error -> {:error, terminal(trigger, :failed, :pipeline_exception)}
  end

  def run(trigger, _context, _ports), do: {:error, terminal(trigger, :failed, :invalid)}

  @spec retry_decision(atom(), map(), non_neg_integer()) :: :stop | {:retry, non_neg_integer()}
  def retry_decision(reason, profile, attempt)
      when reason in @transient and is_map(profile) and is_integer(attempt) and attempt >= 0 do
    if attempt < profile.retry.maximum_attempts do
      delay =
        min(
          profile.retry.base_backoff_ms * Integer.pow(2, attempt),
          profile.retry.maximum_backoff_ms
        )

      {:retry, delay}
    else
      :stop
    end
  end

  def retry_decision(_reason, _profile, _attempt), do: :stop

  @spec recover(map(), map()) :: map()
  def recover(graph_state, context) when is_map(graph_state) and is_map(context) do
    cond do
      graph_state[:enrollment_revision] != context[:enrollment_revision] ->
        %{action: :supersede, reason: :stale_enrollment}

      graph_state[:source_fence] != context[:source_fence] ->
        %{action: :supersede, reason: :stale_source}

      graph_state[:terminal?] == true ->
        %{action: :skip, reason: :already_terminal}

      graph_state[:edition_state] in [:building, :finalized, :linted] ->
        %{action: :resume, reason: :incomplete_edition, attempt_iri: graph_state[:attempt_iri]}

      true ->
        %{action: :reclassify, reason: :graph_rescan}
    end
  end

  def recover(_graph_state, _context), do: %{action: :degrade, reason: :invalid_state}

  defp validate(trigger, context, ports) do
    with true <- Enum.all?(@required_ports, &is_function(ports[&1])),
         true <- trigger.repository_iri == context[:repository_iri],
         true <- trigger.tenant_iri == context[:tenant_iri],
         true <- trigger.source_fence == context[:source_fence],
         true <- trigger.profile_digest == context[:profile_digest],
         true <- trigger.policy_revision == context[:policy_revision],
         true <- context[:lease_current?] == true,
         true <- context[:current_lease_fence] == context[:lease_fence],
         true <- context[:current_source_fence] == context[:source_fence],
         true <- context[:current_enrollment_revision] == context[:enrollment_revision],
         true <- context[:generation_mode] == :deterministic_only,
         true <- context[:reservation_posture] == :zero_token do
      :ok
    else
      _invalid -> {:error, :stale_or_unauthorized}
    end
  end

  defp classify(%{action: action} = classification)
       when action in [:metadata_refresh, :targeted_rebuild, :full_rebuild],
       do: {:continue, classification}

  defp classify(%{action: action}) when action in [:no_change, :stale_only, :unsupported],
    do: {:skip, action}

  defp classify(_classification), do: {:error, :invalid_classification}

  defp exact_compilation(compilation, trigger, context) do
    if compilation[:source_fence] == trigger.source_fence and
         compilation[:profile_digest] == context.profile_digest and
         compilation[:lease_fence] == context.lease_fence and
         compilation[:enrollment_revision] == context.enrollment_revision do
      :ok
    else
      {:error, :compilation_fence_drift}
    end
  end

  defp passing(%{status: :passed, blocking_count: 0}, _kind), do: :ok
  defp passing(_result, :lint), do: {:error, :lint_failed}
  defp passing(_result, :render), do: {:error, :render_failed}

  defp zero_usage(%{tokens: tokens, costs: costs}) do
    if Enum.all?(tokens, fn {_key, value} -> value == 0 end) and
         Enum.all?(costs, fn {_key, value} -> value == 0 end) do
      :ok
    else
      {:error, :nonzero_deterministic_usage}
    end
  end

  defp zero_usage(_usage), do: {:error, :missing_usage}

  defp current_fences(trigger, context) do
    if context[:current_source_fence] == trigger.source_fence and
         context[:current_enrollment_revision] == context[:enrollment_revision] and
         context[:current_lease_fence] == context[:lease_fence] do
      :ok
    else
      {:error, :activation_fence_drift}
    end
  end

  defp terminal(trigger, state, reason) do
    trigger = if is_map(trigger), do: trigger, else: %{}

    value = %{
      trigger_iri: trigger[:iri],
      repository_iri: trigger[:repository_iri],
      state: state,
      reason: reason
    }

    Map.put(value, :digest, Knowledge.repository_wiki_digest(value))
  end
end
