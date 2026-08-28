defmodule JidoCode.Knowledge.RepositoryWiki.Reservation do
  @moduledoc "Repository-scoped worst-case budget reservation with exact effect identity."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Budget
  alias JidoCode.Knowledge.RepositoryWiki.Command
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.PriceProfile
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :idempotency_key,
    :actor_iri,
    :tenant_iri,
    :repository_iri,
    :session_iri,
    :source_revision,
    :edition_iri,
    :attempt_iri,
    :profile_iri,
    :provider,
    :model,
    :price_iri,
    :price_revision,
    :prompt_digest,
    :invocation_iri,
    :budget_iri,
    :budget_revision,
    :currency,
    :liability,
    :state,
    :recorded_at,
    :expires_at,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec admit(map(), map()) ::
          {:ok, t()} | {:duplicate, t()} | {:error, atom() | Error.t()}
  def admit(request, context) when is_map(request) and is_map(context) do
    with :ok <- validate_context(request, context),
         :none <- duplicate(request, context),
         {:ok, liability} <- liability(request, context),
         :ok <- fits?(context.budget, liability, context),
         {:ok, reservation} <- build(request, context, liability) do
      {:ok, reservation}
    else
      {:duplicate, %__MODULE__{} = reservation} -> {:duplicate, reservation}
      {:error, %Error{} = error} -> {:error, error}
      {:error, outcome} when is_atom(outcome) -> {:error, outcome}
      _invalid -> {:error, :invalid}
    end
  rescue
    _error -> {:error, :invalid}
  end

  def admit(_request, _context), do: {:error, :invalid}

  @spec transition(t(), atom(), DateTime.t()) :: {:ok, t()} | {:error, atom()}
  def transition(%__MODULE__{state: state} = reservation, state, %DateTime{}),
    do: {:ok, reservation}

  def transition(%__MODULE__{state: :reserved} = reservation, next, %DateTime{} = at)
      when next in [:consumed, :released, :expired] do
    if next == :expired and DateTime.compare(at, reservation.expires_at) == :lt do
      {:error, :not_expired}
    else
      value = %{reservation | state: next}
      {:ok, %{value | digest: digest(value)}}
    end
  end

  def transition(%__MODULE__{}, _next, %DateTime{}), do: {:error, :terminal}
  def transition(_reservation, _next, _at), do: {:error, :invalid}

  @spec live?(t(), DateTime.t()) :: boolean()
  def live?(%__MODULE__{state: :reserved} = reservation, %DateTime{} = at),
    do: DateTime.compare(at, reservation.expires_at) == :lt

  def live?(%__MODULE__{}, %DateTime{}), do: false

  @spec reserve_command(t(), Budget.t(), map(), keyword()) ::
          {:ok, JidoCode.Knowledge.CommandEnvelope.t()} | {:error, Error.t()}
  def reserve_command(reservation, budget, attributes, options \\ [])

  def reserve_command(
        %__MODULE__{state: :reserved} = reservation,
        %Budget{} = budget,
        attributes,
        options
      )
      when is_map(attributes) and is_list(options) do
    graph = attributes[:control_graph_iri]
    revision = attributes[:expected_control_revision]

    with {:ok, :repository_control} <- GraphRegistry.identify(graph),
         true <- is_integer(revision) and revision > 0,
         true <- reservation.budget_iri == budget.iri,
         true <- reservation.budget_revision == budget.revision,
         target = %{
           family: :repository_control,
           graph_iri: graph,
           operation: :append,
           metadata: %{lifecycle_state: :open},
           additions: statements(reservation),
           supersessions: [],
           invalidations: [],
           removals: []
         },
         guards = [
           {:subject_present, graph, budget.iri},
           {:subject_absent, graph, reservation.iri},
           {:predicate_absent, graph, reservation.invocation_iri,
            "https://jido.run/ontology/factory#invocationBeforeEffect"}
         ],
         command_attributes <-
           attributes
           |> Map.put(:repository_iri, reservation.repository_iri)
           |> Map.put(:source_fence, reservation.source_revision)
           |> Map.put(:expected_graph_revisions, %{graph => revision}),
         {:ok, command} <-
           Command.build(
             "ReserveWikiModelBudget",
             reservation.digest,
             [target],
             guards,
             command_attributes,
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :reserve_wiki_model_budget)}
    end
  end

  def reserve_command(_reservation, _budget, _attributes, _options),
    do: {:error, Error.new(:invalid_input, :reserve_wiki_model_budget)}

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = reservation) do
    jf = "https://jido.run/ontology/factory#"

    [
      {reservation.iri, RDF.type(), RDF.iri(jf <> "WikiReservation")},
      {reservation.iri, jf <> "repositoryScope", RDF.iri(reservation.repository_iri)},
      {reservation.iri, jf <> "tenantScope", RDF.iri(reservation.tenant_iri)},
      {reservation.iri, jf <> "wikiEdition", RDF.iri(reservation.edition_iri)},
      {reservation.iri, jf <> "wikiCompilationAttempt", RDF.iri(reservation.attempt_iri)},
      {reservation.iri, jf <> "wikiBudget", RDF.iri(reservation.budget_iri)},
      {reservation.iri, jf <> "accountingState", RDF.iri(Contract.concept(:wiki_reserved))},
      {reservation.iri, jf <> "usageCurrency", RDF.XSD.String.new(reservation.currency)},
      {reservation.iri, jf <> "usageCost",
       RDF.XSD.Decimal.new(Integer.to_string(reservation.liability.cost_microunits))},
      {reservation.iri, jf <> "generatedAtTime", RDF.XSD.DateTime.new(reservation.recorded_at)},
      {reservation.iri, jf <> "expiresAt", RDF.XSD.DateTime.new(reservation.expires_at)}
    ]
  end

  defp validate_context(request, context) do
    with %Budget{} = budget <- context[:budget],
         %PriceProfile{} = price <- context[:price_profile],
         true <- Budget.current?(budget, request[:recorded_at]),
         true <- request[:budget_revision] == budget.revision,
         true <- request[:price_revision] == price.revision,
         true <- request[:current_fence] == context[:expected_fence],
         true <- request[:enrollment_revision] == context[:enrollment_revision],
         true <- request[:currency] == budget.currency and request[:currency] == price.currency,
         true <- request[:repository_iri] == budget.repository_iri,
         true <- request[:tenant_iri] == budget.tenant_iri,
         true <- request[:actor_iri] == budget.actor_iri,
         true <- request[:profile_iri] == budget.profile_iri,
         true <- request[:provider] == price.provider and request[:model] == price.model,
         true <- DateTime.compare(request[:recorded_at], request[:expires_at]) == :lt,
         :ok <- request_resources(request),
         true <- Contract.digest?(request[:prompt_digest]),
         true <- bounded?(request[:source_revision], 512),
         true <- bounded?(request[:idempotency_key], 160) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, :stale_or_mismatched}
    end
  end

  defp request_resources(request) do
    Enum.reduce_while(
      ~w[actor_iri tenant_iri repository_iri session_iri edition_iri attempt_iri profile_iri invocation_iri]a,
      :ok,
      fn key, :ok ->
        case Contract.resource(request[key]) do
          :ok -> {:cont, :ok}
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end
      end
    )
  end

  defp duplicate(request, context) do
    case Enum.find(
           Map.get(context, :reservations, []),
           &(&1.idempotency_key == request.idempotency_key)
         ) do
      nil ->
        :none

      %__MODULE__{} = existing ->
        if duplicate_material(existing) == duplicate_material(request) do
          {:duplicate, existing}
        else
          {:error, :duplicate_mismatch}
        end
    end
  end

  defp liability(request, context) do
    usage = Map.get(request, :maximum_usage, %{})

    with :ok <- usage?(usage),
         {:ok, cost} <- PriceProfile.cost(context.price_profile, usage, request.recorded_at) do
      {:ok,
       %{
         provider_calls: 1,
         input_tokens: usage.input,
         output_tokens: usage.output,
         cached_tokens: usage.cached,
         reasoning_tokens: usage.reasoning,
         total_tokens: usage.input + usage.output + usage.cached + usage.reasoning,
         cost_microunits: cost
       }}
    end
  end

  defp fits?(budget, liability, context) do
    committed = Map.get(context, :committed, %{})

    reserved =
      context
      |> Map.get(:reservations, [])
      |> Enum.filter(&live?(&1, context.evaluated_at))
      |> Enum.reduce(zero(), fn reservation, totals -> add(totals, reservation.liability) end)

    if Enum.all?(Budget.dimensions(), fn dimension ->
         Map.get(committed, dimension, 0) + reserved[dimension] + liability[dimension] <=
           budget.limits[dimension]
       end) do
      :ok
    else
      {:error, :insufficient_budget}
    end
  end

  defp build(request, context, liability) do
    material = %{
      idempotency_key: request.idempotency_key,
      actor_iri: request.actor_iri,
      tenant_iri: request.tenant_iri,
      repository_iri: request.repository_iri,
      session_iri: request.session_iri,
      source_revision: request.source_revision,
      edition_iri: request.edition_iri,
      attempt_iri: request.attempt_iri,
      profile_iri: request.profile_iri,
      provider: request.provider,
      model: request.model,
      price_iri: context.price_profile.iri,
      price_revision: request.price_revision,
      prompt_digest: request.prompt_digest,
      invocation_iri: request.invocation_iri,
      budget_iri: context.budget.iri,
      budget_revision: request.budget_revision,
      currency: request.currency,
      liability: liability,
      state: :reserved,
      recorded_at: DateTime.truncate(request.recorded_at, :microsecond),
      expires_at: request.expires_at
    }

    value_digest = Contract.digest(material)

    with {:ok, iri} <- ResourceIdentity.deterministic(:wiki_reservation, value_digest) do
      {:ok, struct!(__MODULE__, material |> Map.put(:iri, iri) |> Map.put(:digest, value_digest))}
    end
  end

  defp duplicate_material(%__MODULE__{} = value),
    do:
      Map.take(
        value,
        ~w[actor_iri tenant_iri repository_iri session_iri attempt_iri invocation_iri]a
      )

  defp duplicate_material(value) when is_map(value),
    do:
      Map.take(
        value,
        ~w[actor_iri tenant_iri repository_iri session_iri attempt_iri invocation_iri]a
      )

  defp usage?(usage) when is_map(usage) do
    if Enum.all?([:input, :output, :cached, :reasoning], fn key ->
         is_integer(usage[key]) and usage[key] >= 0
       end) do
      :ok
    else
      {:error, Error.new(:invalid_input, :wiki_reservation_usage)}
    end
  end

  defp usage?(_usage), do: {:error, Error.new(:invalid_input, :wiki_reservation_usage)}
  defp zero, do: Map.new(Budget.dimensions(), &{&1, 0})
  defp add(left, right), do: Map.new(Budget.dimensions(), &{&1, left[&1] + right[&1]})
  defp bounded?(value, maximum), do: is_binary(value) and byte_size(value) in 1..maximum
  defp digest(value), do: value |> Map.from_struct() |> Map.delete(:digest) |> Contract.digest()
end
