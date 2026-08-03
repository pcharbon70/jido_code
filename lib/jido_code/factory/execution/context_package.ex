defmodule JidoCode.Factory.Execution.ContextPackage do
  @moduledoc """
  Reproducible least-privilege context assembled from reviewed graph projections.

  The package records exact source revisions, deterministic omissions, and a
  normalized digest. It is a transient value until an attempt-start command
  commits the durable instruction and context assertions.
  """

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @resource_fields ~w[
    enrollment_iri repository_iri goal_iri task_iri plan_iri lease_iri snapshot_iri actor_iri
    agent_iri capability_iri
  ]a
  @required_fields @resource_fields ++
                     ~w[fencing_token runtime_version instruction source_graph_revisions
                        current_graph_revisions constraints allowed_effects task_allowed_effects
                        expected_artifacts expected_evidence source_items knowledge_items budget
                        assembled_at lease_expires_at lease_state plan_state task_snapshot_iri
                        strict_complete?]a
  @classifications ~w[public internal confidential secret]a
  @default_visible [:public, :internal]
  @max_graphs 20
  @max_items 200

  @enforce_keys [
    :enrollment_iri,
    :repository_iri,
    :goal_iri,
    :task_iri,
    :plan_iri,
    :lease_iri,
    :snapshot_iri,
    :actor_iri,
    :agent_iri,
    :capability_iri,
    :fencing_token,
    :runtime_version,
    :instruction,
    :source_graph_revisions,
    :constraints,
    :allowed_effects,
    :expected_artifacts,
    :expected_evidence,
    :source_items,
    :knowledge_items,
    :omissions,
    :budget,
    :assembled_at,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec build(map()) :: {:ok, t()} | {:error, Error.t()}
  def build(attributes) when is_map(attributes) do
    with true <- Enum.all?(@required_fields, &Map.has_key?(attributes, &1)),
         :ok <- validate_resources(attributes),
         :ok <- validate_authority(attributes),
         :ok <- validate_revisions(attributes),
         {:ok, budget} <- validate_budget(attributes.budget),
         {:ok, instruction} <- validate_instruction(attributes.instruction, budget),
         {:ok, source_items} <- validate_items(attributes.source_items, :source),
         {:ok, knowledge_items} <- validate_items(attributes.knowledge_items, :knowledge),
         {:ok, selected, omissions} <-
           select_items(source_items ++ knowledge_items, attributes, budget),
         {selected_source, selected_knowledge} <-
           Enum.split_with(selected, &(&1.kind == :source)),
         normalized <-
           normalized(
             attributes,
             instruction,
             selected_source,
             selected_knowledge,
             omissions,
             budget
           ),
         digest <- digest(normalized) do
      {:ok, struct!(__MODULE__, Map.put(normalized, :digest, digest))}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:execution_context)
    end
  rescue
    _error -> invalid(:execution_context)
  end

  def build(_attributes), do: invalid(:execution_context)

  defp validate_resources(attributes) do
    if Enum.all?(@resource_fields, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)) and
         Knowledge.validate_resource_identity(attributes.task_snapshot_iri) == :ok do
      :ok
    else
      invalid(:execution_context_identity)
    end
  end

  defp validate_authority(attributes) do
    allowed = attributes.allowed_effects
    task_allowed = attributes.task_allowed_effects

    cond do
      attributes.lease_state != :active ->
        invalid(:execution_context_lease)

      attributes.plan_state != :approved ->
        invalid(:execution_context_plan)

      attributes.strict_complete? != true ->
        invalid(:execution_context_completeness)

      attributes.task_snapshot_iri != attributes.snapshot_iri ->
        invalid(:execution_context_snapshot)

      not is_integer(attributes.fencing_token) or attributes.fencing_token <= 0 ->
        invalid(:execution_context_fence)

      not match?(%DateTime{}, attributes.assembled_at) or
          not match?(%DateTime{}, attributes.lease_expires_at) ->
        invalid(:execution_context_time)

      DateTime.compare(attributes.assembled_at, attributes.lease_expires_at) != :lt ->
        invalid(:execution_context_lease)

      not is_binary(attributes.runtime_version) or
          byte_size(attributes.runtime_version) not in 1..128 ->
        invalid(:execution_context_runtime)

      not is_map(attributes.constraints) or not bounded?(attributes.constraints, 32_768) ->
        invalid(:execution_context_constraints)

      not string_list?(allowed, 100, 128) or not string_list?(task_allowed, 100, 128) ->
        invalid(:execution_context_effects)

      not MapSet.subset?(MapSet.new(allowed), MapSet.new(task_allowed)) ->
        invalid(:execution_context_authority)

      not string_list?(attributes.expected_artifacts, 100, 256) or
          not string_list?(attributes.expected_evidence, 100, 256) ->
        invalid(:execution_context_expectations)

      true ->
        :ok
    end
  end

  defp validate_revisions(attributes) do
    revisions = attributes.source_graph_revisions
    current = attributes.current_graph_revisions

    valid = fn values ->
      is_map(values) and map_size(values) in 1..@max_graphs and
        Enum.all?(values, fn {graph, revision} ->
          match?({:ok, _family}, Knowledge.validate_graph_identity(graph)) and
            is_integer(revision) and revision > 0
        end)
    end

    if valid.(revisions) and valid.(current) and revisions == current,
      do: :ok,
      else: invalid(:execution_context_revisions)
  end

  defp validate_budget(%{max_items: items, max_bytes: bytes, max_tokens: tokens} = budget)
       when items in 1..@max_items and bytes in 1..262_144 and tokens in 1..65_536 do
    {:ok, Map.take(budget, [:max_items, :max_bytes, :max_tokens])}
  end

  defp validate_budget(_budget), do: invalid(:execution_context_budget)

  defp validate_instruction(instruction, budget) when is_binary(instruction) do
    normalized = instruction |> String.trim() |> :unicode.characters_to_nfc_binary()

    if normalized != "" and byte_size(normalized) <= min(budget.max_bytes, 16_384) and
         token_estimate(normalized) <= budget.max_tokens and not secret_marker?(normalized) do
      {:ok, normalized}
    else
      invalid(:execution_context_instruction)
    end
  end

  defp validate_instruction(_instruction, _budget), do: invalid(:execution_context_instruction)

  defp validate_items(items, kind) when is_list(items) and length(items) <= @max_items do
    items
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case validate_item(item, kind) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.sort_by(values, & &1.iri)}
      error -> error
    end
  end

  defp validate_items(_items, _kind), do: invalid(:execution_context_items)

  defp validate_item(item, kind) when is_map(item) do
    with :ok <- Knowledge.validate_resource_identity(item[:iri]),
         content when is_binary(content) and byte_size(content) <= 32_768 <- item[:content],
         classification when classification in @classifications <- item[:classification],
         true <- classification != :secret,
         true <- item[:fresh?] == true,
         true <- item[:contradictory?] == false,
         true <- kind != :knowledge or item[:accepted?] == true,
         true <- not secret_marker?(content) do
      {:ok,
       %{
         iri: item.iri,
         content: content |> String.trim() |> :unicode.characters_to_nfc_binary(),
         classification: classification,
         required?: Map.get(item, :required?, false) == true,
         kind: kind
       }}
    else
      _invalid -> invalid(:execution_context_item)
    end
  end

  defp validate_item(_item, _kind), do: invalid(:execution_context_item)

  defp select_items(items, attributes, budget) do
    visible = Map.get(attributes, :visible_classifications, @default_visible)

    if is_list(visible) and Enum.all?(visible, &(&1 in (@classifications -- [:secret]))) do
      select_items(items, MapSet.new(visible), budget, [], [], %{items: 0, bytes: 0, tokens: 0})
    else
      invalid(:execution_context_visibility)
    end
  end

  defp select_items([], _visible, _budget, selected, omissions, _usage) do
    {:ok, Enum.reverse(selected), Enum.reverse(omissions)}
  end

  defp select_items([item | rest], visible, budget, selected, omissions, usage) do
    item_bytes = byte_size(item.content)
    item_tokens = token_estimate(item.content)

    reason =
      cond do
        not MapSet.member?(visible, item.classification) -> :visibility
        usage.items + 1 > budget.max_items -> :item_budget
        usage.bytes + item_bytes > budget.max_bytes -> :byte_budget
        usage.tokens + item_tokens > budget.max_tokens -> :token_budget
        true -> nil
      end

    cond do
      is_nil(reason) ->
        select_items(
          rest,
          visible,
          budget,
          [item | selected],
          omissions,
          %{
            items: usage.items + 1,
            bytes: usage.bytes + item_bytes,
            tokens: usage.tokens + item_tokens
          }
        )

      item.required? ->
        invalid(:execution_context_required_item)

      true ->
        select_items(
          rest,
          visible,
          budget,
          selected,
          [%{iri: item.iri, kind: item.kind, reason: reason} | omissions],
          usage
        )
    end
  end

  defp normalized(attributes, instruction, source, knowledge, omissions, budget) do
    %{
      enrollment_iri: attributes.enrollment_iri,
      repository_iri: attributes.repository_iri,
      goal_iri: attributes.goal_iri,
      task_iri: attributes.task_iri,
      plan_iri: attributes.plan_iri,
      lease_iri: attributes.lease_iri,
      snapshot_iri: attributes.snapshot_iri,
      actor_iri: attributes.actor_iri,
      agent_iri: attributes.agent_iri,
      capability_iri: attributes.capability_iri,
      fencing_token: attributes.fencing_token,
      runtime_version: attributes.runtime_version,
      instruction: instruction,
      source_graph_revisions: attributes.source_graph_revisions,
      constraints: attributes.constraints,
      allowed_effects: Enum.sort(attributes.allowed_effects),
      expected_artifacts: Enum.sort(attributes.expected_artifacts),
      expected_evidence: Enum.sort(attributes.expected_evidence),
      source_items: source,
      knowledge_items: knowledge,
      omissions: omissions,
      budget: budget,
      assembled_at: DateTime.truncate(attributes.assembled_at, :microsecond)
    }
  end

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp token_estimate(value), do: div(byte_size(value) + 3, 4)

  defp string_list?(values, count, bytes) do
    is_list(values) and length(values) <= count and
      Enum.all?(values, &(is_binary(&1) and byte_size(&1) in 1..bytes))
  end

  defp bounded?(value, limit),
    do: byte_size(:erlang.term_to_binary(value, [:deterministic])) <= limit

  defp secret_marker?(value) do
    Regex.match?(
      ~r/(?:BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,})/,
      value
    )
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
