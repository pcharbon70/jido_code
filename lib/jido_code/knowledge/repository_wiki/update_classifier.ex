defmodule JidoCode.Knowledge.RepositoryWiki.UpdateClassifier do
  @moduledoc """
  Content-addressed repository-wiki update classification and staleness proof.

  Classification is a pure decision over immutable before/after manifests and
  exact authority fences. A queued decision remains usable only while every
  enrollment, source, compiler, and policy fence still matches.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.ResourceIdentity

  @profile "wiki-update-classifier/1.0.0"
  @inputs ~w[
    source manifest lock guide accepted_document policy compiler renderer metadata graph_contract
  ]a
  @priorities ~w[low normal high critical]a
  @actions ~w[
    no_change metadata_refresh targeted_rebuild full_rebuild stale_only unsupported
  ]a
  @maximums %{inputs: 32, affected_pages: 3_072, trigger_bytes: 256}

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      inputs: @inputs,
      actions: @actions,
      priorities: @priorities,
      limits: @maximums,
      unknown_input: :unsupported,
      ambiguous_impact: :full_rebuild,
      generation_mode: :deterministic_only,
      model_calls: 0
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec classify(map(), map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def classify(before, successor, attributes)
      when is_map(before) and is_map(successor) and is_map(attributes) do
    with :ok <- validate_manifests(before, successor),
         :ok <- validate_attributes(attributes),
         :ok <- exact_fence(attributes.classification_fence, attributes.current_fence),
         changed <- changed_inputs(before.values, successor.values),
         {action, reason} <- classify_action(changed, attributes),
         affected <- affected_pages(action, changed, attributes),
         true <- length(affected) <= @maximums.affected_pages do
      value = %{
        profile: @profile,
        profile_digest: profile().digest,
        repository_iri: attributes.repository_iri,
        tenant_iri: attributes.tenant_iri,
        before_manifest_digest: before.digest,
        after_manifest_digest: successor.digest,
        changed_inputs: changed,
        action: action,
        reason: reason,
        change_trigger: attributes.change_trigger,
        causal_revisions: attributes.causal_revisions,
        affected_page_iris: affected,
        requested_profile: attributes.requested_profile,
        priority: attributes.priority,
        classification_fence: attributes.classification_fence,
        source_advanced?:
          attributes.causal_revisions.before_source_revision !=
            attributes.causal_revisions.after_source_revision,
        current_stale?: action not in [:no_change, :metadata_refresh],
        previous_edition_readable?:
          action not in [:no_change, :metadata_refresh] and
            attributes.retained_read_policy == :allow,
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      coalescing_identity =
        Contract.digest(%{
          repository_iri: value.repository_iri,
          after_manifest_digest: value.after_manifest_digest,
          action: value.action,
          affected_page_iris: value.affected_page_iris,
          requested_profile: value.requested_profile,
          fence: value.classification_fence
        })

      result = Map.put(value, :coalescing_identity, coalescing_identity)
      {:ok, Map.put(result, :digest, Contract.digest(result))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_update_classify)
    end
  rescue
    _error -> invalid(:repository_wiki_update_classify)
  end

  def classify(_before, _after, _attributes), do: invalid(:repository_wiki_update_classify)

  @doc "Proves that a persisted classification is still scheduled against the exact authority fence."
  @spec validate_fence(map(), map()) :: :ok | {:error, Error.t()}
  def validate_fence(classification, current_fence)
      when is_map(classification) and is_map(current_fence) do
    with true <- classification[:profile] == @profile,
         true <- exact_digest?(classification, :digest),
         :ok <- exact_fence(classification.classification_fence, current_fence) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_update_fence)
    end
  end

  def validate_fence(_classification, _current_fence),
    do: invalid(:repository_wiki_update_fence)

  @doc "Compares the selected edition fence with current authoritative source and policy state."
  @spec staleness(map(), map(), map()) :: {:ok, map()} | {:error, Error.t()}
  def staleness(edition_fence, authoritative_fence, attributes)
      when is_map(edition_fence) and is_map(authoritative_fence) and is_map(attributes) do
    with :ok <- validate_fence_shape(edition_fence),
         :ok <- validate_fence_shape(authoritative_fence),
         true <- attributes[:retained_read_policy] in [:allow, :deny] do
      reasons =
        [:source_revision, :compiler_digest, :policy_digest, :enrollment_revision]
        |> Enum.filter(&(edition_fence[&1] != authoritative_fence[&1]))

      value = %{
        profile: @profile,
        profile_digest: profile().digest,
        stale?: reasons != [],
        reasons: reasons,
        edition_fence: edition_fence,
        authoritative_fence: authoritative_fence,
        previous_edition_readable?: reasons != [] and attributes.retained_read_policy == :allow,
        requires_reclassification?: reasons != [],
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      {:ok, Map.put(value, :digest, Contract.digest(value))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_staleness)
    end
  rescue
    _error -> invalid(:repository_wiki_staleness)
  end

  def staleness(_edition_fence, _authoritative_fence, _attributes),
    do: invalid(:repository_wiki_staleness)

  @spec manifest(map()) :: {:ok, map()} | {:error, Error.t()}
  def manifest(values) when is_map(values) and map_size(values) <= @maximums.inputs do
    if Enum.all?(values, fn {key, digest} ->
         is_atom(key) and Contract.digest?(digest)
       end) do
      value = %{profile: @profile, values: values |> Enum.sort() |> Map.new()}
      {:ok, Map.put(value, :digest, Contract.digest(value))}
    else
      invalid(:repository_wiki_update_manifest)
    end
  end

  def manifest(_values), do: invalid(:repository_wiki_update_manifest)

  defp validate_manifests(before, successor) do
    cond do
      before[:profile] != @profile or successor[:profile] != @profile ->
        invalid(:repository_wiki_update_manifest)

      not exact_digest?(before, :digest) or not exact_digest?(successor, :digest) ->
        invalid(:repository_wiki_update_manifest)

      not is_map(before[:values]) or not is_map(successor[:values]) or
        map_size(before.values) > @maximums.inputs or
          map_size(successor.values) > @maximums.inputs ->
        invalid(:repository_wiki_update_manifest)

      Enum.sort(Map.keys(before.values)) != Enum.sort(Map.keys(successor.values)) ->
        invalid(:repository_wiki_update_manifest)

      not Enum.all?(before.values, fn {key, digest} ->
        is_atom(key) and Contract.digest?(digest) and Contract.digest?(successor.values[key])
      end) ->
        invalid(:repository_wiki_update_manifest)

      true ->
        :ok
    end
  end

  defp validate_attributes(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:repository_iri]),
         :ok <- ResourceIdentity.validate(attributes[:tenant_iri]),
         true <- is_binary(attributes[:change_trigger]),
         true <- byte_size(attributes.change_trigger) in 1..@maximums.trigger_bytes,
         true <- attributes[:requested_profile] == Protocol.compiler_profile(),
         true <- attributes[:priority] in @priorities,
         true <- attributes[:retained_read_policy] in [:allow, :deny],
         :ok <- validate_causal_revisions(attributes[:causal_revisions]),
         :ok <- validate_fence_shape(attributes[:classification_fence]),
         :ok <- validate_fence_shape(attributes[:current_fence]),
         :ok <- validate_impact(attributes[:impact]) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:repository_wiki_update_attributes)
    end
  end

  defp validate_causal_revisions(revisions) when is_map(revisions) do
    if Map.keys(revisions) |> Enum.sort() ==
         [:after_source_revision, :before_source_revision, :trigger_revision] and
         Enum.all?(revisions, fn {_key, value} -> Contract.digest?(value) end) do
      :ok
    else
      invalid(:repository_wiki_update_revisions)
    end
  end

  defp validate_causal_revisions(_revisions), do: invalid(:repository_wiki_update_revisions)

  defp validate_impact(impact) when is_map(impact) do
    pages = impact[:affected_page_iris]

    cond do
      Enum.sort(Map.keys(impact)) != [:affected_page_iris, :digest, :profile, :proven?] ->
        invalid(:repository_wiki_update_impact)

      impact[:profile] != "wiki-impact-manifest/1.0.0" or not exact_digest?(impact, :digest) ->
        invalid(:repository_wiki_update_impact)

      not is_boolean(impact[:proven?]) or not is_list(pages) or
          length(pages) > @maximums.affected_pages ->
        invalid(:repository_wiki_update_impact)

      not Enum.all?(pages, &(ResourceIdentity.validate(&1) == :ok)) ->
        invalid(:repository_wiki_update_impact)

      pages != Enum.sort(Enum.uniq(pages)) ->
        invalid(:repository_wiki_update_impact)

      true ->
        :ok
    end
  end

  defp validate_impact(_impact), do: invalid(:repository_wiki_update_impact)

  defp validate_fence_shape(fence) when is_map(fence) do
    expected_keys = [:compiler_digest, :enrollment_revision, :policy_digest, :source_revision]

    cond do
      Map.keys(fence) |> Enum.sort() != expected_keys ->
        invalid(:repository_wiki_update_fence)

      not is_integer(fence[:enrollment_revision]) or fence.enrollment_revision < 0 ->
        invalid(:repository_wiki_update_fence)

      not Enum.all?([:compiler_digest, :policy_digest, :source_revision], fn key ->
        Contract.digest?(fence[key])
      end) ->
        invalid(:repository_wiki_update_fence)

      true ->
        :ok
    end
  end

  defp validate_fence_shape(_fence), do: invalid(:repository_wiki_update_fence)

  defp exact_fence(expected, current) do
    with :ok <- validate_fence_shape(expected),
         :ok <- validate_fence_shape(current) do
      if expected == current, do: :ok, else: conflict(:repository_wiki_update_fence)
    end
  end

  defp changed_inputs(before, successor) do
    before
    |> Map.keys()
    |> Enum.filter(&(before[&1] != successor[&1]))
    |> Enum.sort()
  end

  defp classify_action([], attributes) do
    if attributes.causal_revisions.before_source_revision ==
         attributes.causal_revisions.after_source_revision do
      {:no_change, :identical_admitted_inputs}
    else
      {:stale_only, :source_revision_advanced_without_content_change}
    end
  end

  defp classify_action(changed, attributes) do
    known = Enum.filter(changed, &(&1 in @inputs))
    unknown = changed -- known

    cond do
      unknown != [] ->
        {:unsupported, :unknown_input_classification}

      changed == [:metadata] ->
        {:metadata_refresh, :metadata_observation_changed}

      Enum.all?(changed, &(&1 in [:guide, :accepted_document, :source])) and
        attributes.impact.proven? and attributes.impact.affected_page_iris != [] ->
        {:targeted_rebuild, targeted_reason(changed)}

      Enum.any?(changed, &(&1 in [:manifest, :lock])) ->
        {:full_rebuild, :dependency_inputs_changed}

      Enum.any?(changed, &(&1 in [:policy, :compiler, :renderer, :graph_contract])) ->
        {:full_rebuild, :compiler_contract_changed}

      true ->
        {:full_rebuild, :impact_not_proven}
    end
  end

  defp targeted_reason([:guide]), do: :guide_changed
  defp targeted_reason([:accepted_document]), do: :accepted_document_changed
  defp targeted_reason([:source]), do: :source_changed
  defp targeted_reason(_changed), do: :bounded_sources_changed

  defp affected_pages(:targeted_rebuild, _changed, attributes),
    do: attributes.impact.affected_page_iris

  defp affected_pages(:metadata_refresh, _changed, attributes),
    do: attributes.impact.affected_page_iris

  defp affected_pages(_action, _changed, _attributes), do: []

  defp exact_digest?(value, key) when is_map(value) do
    digest = value[key]
    Contract.digest?(digest) and Contract.digest(Map.delete(value, key)) == digest
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, Error.new(:conflict, operation)}
end
