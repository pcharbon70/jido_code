defmodule JidoCode.Knowledge.Memory.RetrievalRequest do
  @moduledoc """
  Closed, authorization-bound request for model-influencing memory retrieval.

  Construction derives the only admissible first-stage partition. Candidate
  generators receive that partition from the request and cannot select scope,
  purpose, time, classification, or erasure boundaries independently.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Security.DataPolicy

  @enforce_keys [
    :iri,
    :digest,
    :attempt_iri,
    :actor_iri,
    :repository_iri,
    :tenant_iri,
    :actor_scope_iri,
    :task_iri,
    :purpose,
    :plan_phase,
    :effective_at,
    :provider_profile_iri,
    :data_ceiling,
    :allowed_classifications,
    :categories,
    :trust_levels,
    :budgets,
    :query_version,
    :ranking_version,
    :index_version,
    :partition
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @categories ~w[attempt_history failure lineage policy source test current_state]a
  @trust_levels ~w[verified accepted asserted observed untrusted]a
  @purposes ~w[managed_continuity failure_recovery incident_response evaluation dataset_construction]a
  @classifications DataPolicy.classifications()
  @query_version QueryCatalog.history_version()
  @budget_limits %{
    item_limit: 100,
    graph_limit: 20,
    byte_limit: 256_000,
    token_limit: 65_536,
    time_limit_ms: 5_000
  }
  @revision ~r/^[a-z0-9][a-z0-9._-]{0,63}$/

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    resources = ~w[
      attempt_iri actor_iri repository_iri tenant_iri actor_scope_iri task_iri provider_profile_iri
    ]a

    with :ok <- validate_resources(attributes, resources),
         purpose when purpose in @purposes <- attributes[:purpose],
         plan_phase when is_binary(plan_phase) and byte_size(plan_phase) in 1..64 <-
           attributes[:plan_phase],
         true <- safe_text?(plan_phase),
         %DateTime{} = effective_at <- attributes[:effective_at],
         data_ceiling when data_ceiling in @classifications <- attributes[:data_ceiling],
         {:ok, classifications} <-
           closed_atoms(attributes[:allowed_classifications], @classifications, false),
         true <- data_ceiling in classifications,
         {:ok, categories} <- closed_atoms(attributes[:categories], @categories, false),
         {:ok, trust_levels} <- closed_atoms(attributes[:trust_levels], @trust_levels, false),
         {:ok, budgets} <- budgets(attributes[:budgets]),
         query_version when query_version == @query_version <- attributes[:query_version],
         ranking_version when is_binary(ranking_version) <- attributes[:ranking_version],
         true <- Regex.match?(@revision, ranking_version),
         index_version when is_binary(index_version) <- attributes[:index_version],
         true <- Regex.match?(@revision, index_version),
         {:ok, partition} <- partition(attributes),
         material <-
           Map.take(attributes, [
             :attempt_iri,
             :actor_iri,
             :repository_iri,
             :tenant_iri,
             :actor_scope_iri,
             :task_iri,
             :purpose,
             :plan_phase,
             :provider_profile_iri,
             :data_ceiling,
             :query_version,
             :ranking_version,
             :index_version
           ]),
         digest <-
           digest_term({
             material,
             DateTime.to_iso8601(effective_at),
             classifications,
             categories,
             trust_levels,
             budgets,
             partition.partition_digest
           }),
         {:ok, iri} <- ResourceIdentity.deterministic(:memory_retrieval_request, digest) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(material, %{
           iri: iri,
           digest: digest,
           effective_at: DateTime.truncate(effective_at, :microsecond),
           allowed_classifications: classifications,
           categories: categories,
           trust_levels: trust_levels,
           budgets: budgets,
           partition: partition
         })
       )}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec categories() :: [atom()]
  def categories, do: @categories

  @spec trust_levels() :: [atom()]
  def trust_levels, do: @trust_levels

  defp partition(attributes) do
    authorization = attributes[:authorization]

    if is_map(authorization) and
         authorization[:repository_iri] == attributes[:repository_iri] and
         authorization[:tenant_iri] == attributes[:tenant_iri] and
         authorization[:actor_scope_iri] == attributes[:actor_scope_iri] and
         authorization[:purpose] == attributes[:purpose] and
         authorization[:data_ceiling] == attributes[:data_ceiling] do
      Guardrails.authorize_candidate_partition(authorization)
    else
      {:error, Error.new(:unauthorized, :memory_retrieval_partition)}
    end
  end

  defp budgets(values) when is_map(values) and map_size(values) == map_size(@budget_limits) do
    if Enum.all?(@budget_limits, fn {name, maximum} ->
         value = values[name]
         is_integer(value) and value in 1..maximum
       end) and MapSet.new(Map.keys(values)) == MapSet.new(Map.keys(@budget_limits)) do
      {:ok, Map.take(values, Map.keys(@budget_limits))}
    else
      invalid()
    end
  end

  defp budgets(_values), do: invalid()

  defp validate_resources(attributes, names) do
    if Enum.all?(names, &(ResourceIdentity.validate(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid()
  end

  defp closed_atoms(values, allowed, allow_empty?) when is_list(values) do
    normalized = Enum.sort(values)

    if (allow_empty? or normalized != []) and length(normalized) == length(Enum.uniq(normalized)) and
         Enum.all?(normalized, &(&1 in allowed)),
       do: {:ok, normalized},
       else: invalid()
  end

  defp closed_atoms(_values, _allowed, _allow_empty?), do: invalid()

  defp safe_text?(value), do: not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp digest_term(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :memory_retrieval_request)}
end
