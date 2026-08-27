defmodule JidoCode.Knowledge.RepositoryWiki.MixReconciler do
  @moduledoc "Deterministic coexistence and conflict rules for repository Mix facts."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.LockParser
  alias JidoCode.Knowledge.RepositoryWiki.MixStatic

  @profile "mix-reconcile/1.0.0"

  @spec profile() :: map()
  def profile do
    value = %{
      revision: @profile,
      precedence: [:accepted_graph, :literal_declaration, :sandbox_observation],
      conflicts: :preserve_all_candidates,
      source_fencing: :exact,
      model_calls: 0
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  @spec reconcile(map(), map() | nil, map() | nil, list(), map()) ::
          {:ok, map()} | {:error, Error.t()}
  def reconcile(static, lock, observation, accepted_facts \\ [], attributes \\ %{})

  def reconcile(static, lock, observation, accepted_facts, attributes)
      when is_map(static) and (is_map(lock) or is_nil(lock)) and
             (is_map(observation) or is_nil(observation)) and is_list(accepted_facts) and
             is_map(attributes) do
    with :ok <- validate_inputs(static, lock, observation, accepted_facts, attributes),
         {:ok, fields, field_gaps} <- reconcile_fields(static, observation, accepted_facts),
         gaps <- gaps(static, lock, observation, field_gaps) do
      result = %{
        profile: @profile,
        profile_digest: profile().digest,
        source_digest: static.source_digest,
        lock_digest: if(lock, do: lock.source_digest, else: nil),
        source_fence: attributes.source_fence,
        toolchain_digest: attributes.toolchain_digest,
        parser_profile: static.profile,
        parser_profile_digest: static.profile_digest,
        lock_profile: if(lock, do: lock.profile, else: nil),
        lock_profile_digest: if(lock, do: lock.profile_digest, else: nil),
        sandbox_profile: if(observation, do: observation.profile, else: nil),
        sandbox_profile_digest: if(observation, do: observation.profile_digest, else: nil),
        policy_revision: attributes.policy_revision,
        fields: fields,
        declared_dependencies: static.dependencies,
        observed_dependencies: if(observation, do: observation.dependencies, else: []),
        lock_entries: if(lock, do: lock.entries, else: []),
        gaps: gaps,
        completeness: completeness(fields, gaps),
        model_calls: 0,
        model_input_tokens: 0,
        model_output_tokens: 0,
        usage_cost_microunits: 0
      }

      {:ok, Map.put(result, :digest, Contract.digest(result))}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  rescue
    _error -> invalid()
  end

  def reconcile(_static, _lock, _observation, _accepted_facts, _attributes), do: invalid()

  defp validate_inputs(static, lock, observation, accepted_facts, attributes) do
    cond do
      static[:profile] != "mix-static/1.0.0" or not Contract.digest?(static[:digest]) or
        not Contract.digest?(static[:source_digest]) or
          static[:profile_digest] != MixStatic.profile().digest ->
        invalid()

      attributes[:source_digest] != static.source_digest or
        attributes[:source_fence] == nil or
        attributes[:toolchain_digest] == nil or
          attributes[:policy_revision] == nil ->
        conflict()

      lock &&
          (lock[:profile] != "mix-lock/1.0.0" or not Contract.digest?(lock[:digest]) or
             lock[:profile_digest] != LockParser.profile().digest or
             attributes[:lock_digest] != lock.source_digest) ->
        conflict()

      observation &&
          (observation[:profile] != "mix-sandbox/1.0.0" or
             not Contract.digest?(observation[:digest]) or
             observation.source_digest != static.source_digest or
             observation.source_fence != attributes.source_fence or
             observation.toolchain_digest != attributes.toolchain_digest or
             observation.policy_revision != attributes.policy_revision) ->
        conflict()

      length(accepted_facts) > 256 or
          not Enum.all?(accepted_facts, &valid_accepted_fact?(&1, attributes)) ->
        invalid()

      true ->
        :ok
    end
  end

  defp valid_accepted_fact?(fact, attributes) when is_map(fact) do
    is_binary(fact[:name]) and byte_size(fact.name) in 1..128 and
      fact[:source_fence] == attributes.source_fence and
      is_integer(fact[:revision]) and fact.revision >= 0 and
      Contract.digest?(fact[:source_digest])
  end

  defp valid_accepted_fact?(_fact, _attributes), do: false

  defp reconcile_fields(static, observation, accepted_facts) do
    static_candidates = Enum.map(static.fields, &static_candidate(&1, static))

    observed_candidates =
      if observation,
        do: Enum.map(observation.fields, &observed_candidate(&1, observation)),
        else: []

    accepted_candidates = Enum.map(accepted_facts, &accepted_candidate/1)

    candidates = static_candidates ++ observed_candidates ++ accepted_candidates

    fields =
      candidates
      |> Enum.group_by(& &1.name)
      |> Enum.map(fn {name, values} -> reconcile_field(name, values) end)
      |> Enum.sort_by(& &1.name)

    gaps =
      fields
      |> Enum.filter(&(&1.state in [:conflicting, :dynamic, :unsupported, :unavailable]))
      |> Enum.map(&%{kind: &1.state, field: &1.name, blocking: &1.state == :conflicting})

    {:ok, fields, gaps}
  end

  defp static_candidate(field, static) do
    %{
      name: field.name,
      value: field.value,
      state: field.state,
      source_kind: :mix_exs,
      source_location: field.location,
      source_revision: static.source_digest,
      profile: static.profile,
      confidence: if(field.state == :static_exact, do: :verified_literal, else: :unresolved),
      freshness: :fresh,
      authority: :declared
    }
  end

  defp observed_candidate(field, observation) do
    %{
      name: field.name,
      value: field.value,
      state: field.state,
      source_kind: :sandbox_observation,
      source_location: nil,
      source_revision: observation.source_digest,
      profile: observation.profile,
      confidence: :observed,
      freshness: :fresh,
      authority: :observed
    }
  end

  defp accepted_candidate(fact) do
    %{
      name: fact.name,
      value: fact[:value],
      state: :accepted,
      source_kind: :accepted_graph,
      source_location: nil,
      source_revision: fact.source_digest,
      profile: fact[:profile] || "accepted-graph",
      confidence: :accepted,
      freshness: fact[:freshness] || :fresh,
      authority: :accepted
    }
  end

  defp reconcile_field(name, candidates) do
    material = Enum.reject(candidates, &is_nil(&1.value))
    values = material |> Enum.map(& &1.value) |> Enum.uniq()
    static = Enum.find(candidates, &(&1.authority == :declared and &1.state == :static_exact))
    observed = Enum.find(candidates, &(&1.authority == :observed and &1.state == :observed))
    accepted = Enum.find(candidates, &(&1.authority == :accepted))

    state =
      cond do
        length(values) > 1 -> :conflicting
        static && observed && static.value == observed.value -> :verified
        static -> :declared
        observed -> :observed
        accepted -> :accepted
        Enum.any?(candidates, &(&1.state == :unsupported)) -> :unsupported
        Enum.any?(candidates, &(&1.state in [:unavailable])) -> :unavailable
        true -> :dynamic
      end

    %{
      name: name,
      state: state,
      value: if(length(values) == 1, do: hd(values), else: nil),
      candidates: Enum.map(candidates, &Map.put(&1, :conflict_state, conflict_state(&1, values)))
    }
  end

  defp conflict_state(_candidate, values) when length(values) <= 1, do: :none
  defp conflict_state(_candidate, _values), do: :conflicting

  defp gaps(static, lock, observation, field_gaps) do
    static_gaps =
      Enum.map(static.diagnostics, fn diagnostic ->
        %{
          kind: diagnostic.state,
          field: diagnostic.field,
          code: diagnostic.code,
          blocking: false
        }
      end)

    lock_gaps =
      cond do
        is_nil(lock) ->
          [%{kind: :missing_lock, field: "mix.lock", blocking: true}]

        lock.unsupported_count > 0 ->
          [%{kind: :unsupported_lock, field: "mix.lock", blocking: true}]

        true ->
          []
      end

    observation_gaps =
      cond do
        is_nil(observation) and static.coverage.dynamic_required > 0 ->
          [%{kind: :missing_observation, field: "mix.exs", blocking: true}]

        observation && observation.status != :completed ->
          [%{kind: :incomplete_observation, field: "mix.exs", blocking: true}]

        observation && observation.truncated ->
          [%{kind: :truncated_observation, field: "mix.exs", blocking: true}]

        true ->
          []
      end

    (field_gaps ++ static_gaps ++ lock_gaps ++ observation_gaps)
    |> Enum.uniq()
    |> Enum.sort_by(&{to_string(&1.kind), &1.field, to_string(Map.get(&1, :code, ""))})
  end

  defp completeness(fields, gaps) do
    blocking = Enum.count(gaps, & &1.blocking)

    %{
      state: if(blocking == 0, do: :complete, else: :partial),
      field_count: length(fields),
      gap_count: length(gaps),
      blocking_gap_count: blocking,
      conflict_count: Enum.count(fields, &(&1.state == :conflicting))
    }
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :repository_wiki_mix_reconcile)}
  defp conflict, do: {:error, Error.new(:conflict, :repository_wiki_mix_reconcile)}
end
