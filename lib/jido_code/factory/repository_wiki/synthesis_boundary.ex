defmodule JidoCode.Factory.RepositoryWiki.SynthesisBoundary do
  @moduledoc "Provider-neutral synthesis boundary that is structurally unavailable in V1 production."

  @required_ports [:commit_invocation, :adapter, :normalize, :lint, :review]

  @spec production_adapter_catalog() :: []
  def production_adapter_catalog, do: []

  @spec invoke(map(), map(), map()) :: {:ok, map()} | {:error, map()}
  def invoke(request, context, ports)
      when is_map(request) and is_map(context) and is_map(ports) do
    with :ok <- available(request, context, ports),
         {:ok, commit_receipt} <- ports.commit_invocation.(request, context),
         true <- committed?(commit_receipt) do
      dispatch(request, context, ports, commit_receipt)
    else
      {:error, %{outcome: _outcome} = error} -> {:error, error}
      {:error, reason} -> {:error, failure(reason, false)}
      false -> {:error, failure(:uncommitted_invocation, false)}
      _invalid -> {:error, failure(:invalid_invocation, false)}
    end
  rescue
    _error -> {:error, failure(:boundary_exception, false)}
  end

  def invoke(_request, _context, _ports), do: {:error, failure(:invalid_request, false)}

  defp dispatch(request, context, ports, commit_receipt) do
    with {:ok, observation} <- ports.adapter.(request, context),
         {:ok, normalized} <- ports.normalize.(observation, request, context),
         :ok <- normalized_usage(normalized, request, context),
         {:ok, lint} <- ports.lint.(normalized.output, request, context),
         :ok <- passing(lint),
         {:ok, review} <- ports.review.(normalized.output, lint, request, context),
         true <- review[:decision] in [:approved, :pending_human_review] do
      {:ok,
       %{
         outcome: :observed,
         effect_started?: true,
         invocation_receipt: commit_receipt,
         output: normalized.output,
         usage: normalized.usage,
         lint: lint,
         review: review,
         activation_eligible?: false
       }}
    else
      {:error, reason} -> {:error, failure(reason, true)}
      false -> {:error, failure(:review_failed, true)}
      _invalid -> {:error, failure(:invalid_observation, true)}
    end
  rescue
    _error -> {:error, failure(:boundary_exception, true)}
  end

  defp available(request, context, ports) do
    cond do
      context[:deployment] == :production ->
        {:error, failure(:unavailable, false)}

      context[:deployment] != :test ->
        {:error, failure(:unavailable, false)}

      context[:adapter_catalog] == [] ->
        {:error, failure(:unavailable, false)}

      not Enum.all?(@required_ports, &is_function(ports[&1])) ->
        {:error, failure(:boundary_unavailable, false)}

      context[:wiki_enrolled?] != true or context[:synthesis_opt_in?] != true ->
        {:error, failure(:missing_opt_in, false)}

      context[:profile_enabled?] != true or context[:price_enabled?] != true ->
        {:error, failure(:disabled_profile, false)}

      context[:worker_ready?] != true ->
        {:error, failure(:worker_unavailable, false)}

      context[:reservation_state] != :reserved or context[:reservation_current?] != true ->
        {:error, failure(:reservation_unavailable, false)}

      request.reservation_iri != context[:reservation_iri] ->
        {:error, failure(:reservation_mismatch, false)}

      request.profile_iri != context[:profile_iri] or request.price_iri != context[:price_iri] ->
        {:error, failure(:profile_mismatch, false)}

      request.source_fence != context[:source_fence] ->
        {:error, failure(:source_drift, false)}

      request.provider != context[:provider] or request.model != context[:model] ->
        {:error, failure(:provider_mismatch, false)}

      true ->
        :ok
    end
  end

  defp committed?(receipt), do: receipt[:outcome] in [:committed, :duplicate_committed]

  defp normalized_usage(normalized, request, context) do
    usage = normalized[:usage]

    if is_map(normalized[:output]) and is_map(usage) and
         usage[:provider_request_iri] == context[:provider_request_iri] and
         usage[:provider] == request.provider and usage[:model] == request.model and
         usage[:reservation_iri] == request.reservation_iri and
         usage[:invocation_iri] == request.invocation_iri and
         Enum.all?([:input, :output, :cached, :reasoning], fn key ->
           is_integer(usage[key]) and usage[key] >= 0 and usage[key] <= request.token_limits[key]
         end) do
      :ok
    else
      {:error, :usage_drift}
    end
  end

  defp passing(%{status: :passed, blocking_count: 0}), do: :ok
  defp passing(_lint), do: {:error, :lint_failed}

  defp failure(outcome, effect_started?),
    do: %{outcome: outcome, effect_started?: effect_started?, activation_eligible?: false}
end
