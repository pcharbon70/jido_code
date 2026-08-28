defmodule JidoCode.Knowledge.RepositoryWiki.UsageAccounting do
  @moduledoc "Terminal, idempotent repository wiki token and cost accounting."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Command
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.PriceProfile
  alias JidoCode.Knowledge.RepositoryWiki.Protocol
  alias JidoCode.Knowledge.RepositoryWiki.Reservation
  alias JidoCode.Knowledge.ResourceIdentity

  @terminal_states [
    :success,
    :rejected_before_effect,
    :failed_before_effect,
    :failed_after_effect,
    :cancelled,
    :timed_out,
    :usage_pending,
    :usage_unknown
  ]

  @spec terminal_states() :: [atom()]
  def terminal_states, do: @terminal_states

  @spec deterministic(map()) :: {:ok, map()} | {:error, Error.t()}
  def deterministic(attributes) when is_map(attributes) do
    build(
      attributes,
      %{input: 0, output: 0, cached: 0, reasoning: 0},
      %{reserved: 0, measured: 0, charged: 0, refunded: 0, unknown: 0},
      :deterministic_only
    )
  end

  def deterministic(_attributes), do: invalid(:wiki_deterministic_usage)

  @spec measured(map(), PriceProfile.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def measured(raw, %PriceProfile{} = price, attributes)
      when is_map(raw) and is_map(attributes) do
    with :ok <- measured_usage(raw),
         :ok <- matching_price(raw, price),
         {:ok, charged} <- PriceProfile.cost(price, raw, attributes.recorded_at),
         costs = %{
           reserved: attributes.reserved_cost,
           measured: charged,
           charged: charged,
           refunded: max(attributes.reserved_cost - charged, 0),
           unknown: 0
         },
         {:ok, record} <-
           build(
             attributes,
             Map.take(raw, [:input, :output, :cached, :reasoning]),
             costs,
             :synthesis_allowed
           ) do
      {:ok,
       Map.merge(record, %{
         provider_request_iri: raw.provider_request_iri,
         provider: raw.provider,
         model: raw.model,
         region: raw.region,
         price_iri: price.iri,
         price_revision: price.revision,
         raw_evidence_digest: raw.raw_evidence_digest
       })}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  def measured(_raw, _price, _attributes), do: invalid(:wiki_measured_usage)

  @spec reconcile(Reservation.t(), map(), map()) ::
          {:ok, %{reservation: Reservation.t(), usage: map()}}
          | {:duplicate, map()}
          | {:error, atom()}
  def reconcile(%Reservation{} = reservation, usage, context)
      when is_map(usage) and is_map(context) do
    if mismatched?(reservation, usage, context) do
      {:error, :mismatched_usage}
    else
      reconcile_current(reservation, usage, context)
    end
  end

  def reconcile(_reservation, _usage, _context), do: {:error, :invalid}

  defp reconcile_current(reservation, usage, context) do
    case existing(usage, context) do
      {:duplicate, existing} ->
        {:duplicate, existing}

      :none ->
        case Reservation.transition(reservation, reservation_state(usage), usage.recorded_at) do
          {:ok, transitioned} -> {:ok, %{reservation: transitioned, usage: usage}}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp mismatched?(reservation, usage, context) do
    Enum.any?(
      [
        {usage.reservation_iri, reservation.iri},
        {usage.attempt_iri, reservation.attempt_iri},
        {usage.invocation_iri, reservation.invocation_iri},
        {usage.price_revision, reservation.price_revision},
        {usage.accounting_fence, context[:accounting_fence]}
      ],
      fn {observed, expected} -> observed != expected end
    )
  end

  @spec record_command(map(), map(), keyword()) ::
          {:ok, JidoCode.Knowledge.CommandEnvelope.t()} | {:error, Error.t()}
  def record_command(usage, attributes, options \\ [])

  def record_command(usage, attributes, options)
      when is_map(usage) and is_map(attributes) and is_list(options) do
    run_graph = attributes[:run_graph_iri]
    control_graph = attributes[:control_graph_iri]
    run_revision = attributes[:expected_run_revision]
    control_revision = attributes[:expected_control_revision]

    with {:ok, :run_attempt} <- GraphRegistry.identify(run_graph),
         {:ok, :repository_control} <- GraphRegistry.identify(control_graph),
         :ok <- positive_revision(run_revision),
         :ok <- positive_revision(control_revision),
         {:ok, _state} <- terminal_state(usage.state),
         target = %{
           family: :run_attempt,
           graph_iri: run_graph,
           operation: :append,
           metadata: %{lifecycle_state: :open},
           additions: statements(usage),
           supersessions: [],
           invalidations: [],
           removals: []
         },
         guards =
           [{:subject_absent, run_graph, usage.iri}] ++
             reservation_guard(control_graph, usage[:reservation_iri]),
         command_attributes <-
           attributes
           |> Map.put(:command_version, Protocol.runtime_semantic_version())
           |> Map.put(:repository_iri, usage.repository_iri)
           |> Map.put(:source_fence, usage.source_revision)
           |> Map.put(:expected_graph_revisions, %{
             run_graph => run_revision,
             control_graph => control_revision
           }),
         {:ok, command} <-
           Command.build(
             "RecordWikiModelUsage",
             usage.digest,
             [target],
             guards,
             command_attributes,
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:record_wiki_model_usage)
    end
  end

  def record_command(_usage, _attributes, _options), do: invalid(:record_wiki_model_usage)

  @spec statements(map()) :: [tuple()]
  def statements(usage) when is_map(usage) do
    jf = "https://jido.run/ontology/factory#"

    [
      {usage.iri, RDF.type(), RDF.iri(jf <> "WikiUsageRecord")},
      {usage.iri, jf <> "repositoryScope", RDF.iri(usage.repository_iri)},
      {usage.iri, jf <> "tenantScope", RDF.iri(usage.tenant_iri)},
      {usage.iri, jf <> "wikiEdition", RDF.iri(usage.edition_iri)},
      {usage.iri, jf <> "wikiCompilationAttempt", RDF.iri(usage.attempt_iri)},
      {usage.iri, jf <> "accountingState", RDF.iri(Contract.concept(usage.state))},
      {usage.iri, jf <> "modelInputTokens", RDF.XSD.NonNegativeInteger.new(usage.tokens.input)},
      {usage.iri, jf <> "modelOutputTokens", RDF.XSD.NonNegativeInteger.new(usage.tokens.output)},
      {usage.iri, jf <> "modelCachedTokens", RDF.XSD.NonNegativeInteger.new(usage.tokens.cached)},
      {usage.iri, jf <> "modelReasoningTokens",
       RDF.XSD.NonNegativeInteger.new(usage.tokens.reasoning)},
      {usage.iri, jf <> "usageCurrency", RDF.XSD.String.new(usage.currency)},
      {usage.iri, jf <> "usageCost", RDF.XSD.Decimal.new(Integer.to_string(usage.costs.charged))},
      {usage.iri, jf <> "generatedAtTime", RDF.XSD.DateTime.new(usage.recorded_at)}
      | optional_reservation(usage.iri, usage[:reservation_iri])
    ]
  end

  defp build(attributes, tokens, costs, generation_mode) do
    with :ok <- common(attributes),
         {:ok, state} <- terminal_state(attributes[:state]),
         :ok <- nonnegative(tokens, costs),
         material <- %{
           repository_iri: attributes.repository_iri,
           tenant_iri: attributes.tenant_iri,
           actor_iri: attributes.actor_iri,
           attempt_iri: attributes.attempt_iri,
           edition_iri: attributes.edition_iri,
           reservation_iri: attributes[:reservation_iri],
           invocation_iri: attributes[:invocation_iri],
           generation_mode: generation_mode,
           state: state,
           trigger: attributes.trigger,
           source_revision: attributes.source_revision,
           profile_iri: attributes.profile_iri,
           tokens: tokens,
           costs: costs,
           currency: attributes.currency,
           local_work: attributes.local_work,
           recorded_at: DateTime.truncate(attributes.recorded_at, :microsecond)
         },
         digest <- Contract.digest(material),
         {:ok, iri} <- ResourceIdentity.deterministic(:wiki_usage_record, digest) do
      {:ok, material |> Map.put(:iri, iri) |> Map.put(:digest, digest)}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  rescue
    _error -> invalid(:wiki_usage_record)
  end

  defp common(attributes) do
    resource_keys = ~w[repository_iri tenant_iri actor_iri attempt_iri edition_iri profile_iri]a

    with :ok <- required_resources(resource_keys, attributes),
         :ok <- Contract.optional_resource(attributes[:reservation_iri]),
         :ok <- Contract.optional_resource(attributes[:invocation_iri]),
         :ok <- bounded_text(attributes[:trigger], 128),
         :ok <- bounded_text(attributes[:source_revision], 512),
         :ok <- currency(attributes[:currency]),
         :ok <- local_work(attributes[:local_work]),
         :ok <- recorded_at(attributes[:recorded_at]) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp measured_usage(raw) do
    with :ok <- nonnegative(Map.take(raw, [:input, :output, :cached, :reasoning]), nil),
         :ok <- required_texts([:provider, :model, :region], raw, 128),
         :ok <- Contract.resource(raw[:provider_request_iri]),
         :ok <- digest(raw[:raw_evidence_digest]) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp existing(usage, context) do
    case Enum.find(Map.get(context, :usage_records, []), &(&1.iri == usage.iri)) do
      nil -> :none
      existing -> {:duplicate, existing}
    end
  end

  defp reservation_state(%{state: state}) when state in [:usage_pending, :usage_unknown],
    do: :consumed

  defp reservation_state(%{state: state})
       when state in [:rejected_before_effect, :failed_before_effect],
       do: :released

  defp reservation_state(_usage), do: :consumed

  defp reservation_guard(_control_graph, nil), do: []

  defp reservation_guard(control_graph, reservation_iri),
    do: [{:subject_present, control_graph, reservation_iri}]

  defp optional_reservation(_usage_iri, nil), do: []

  defp optional_reservation(usage_iri, reservation_iri),
    do: [
      {usage_iri, "https://jido.run/ontology/factory#wikiReservation", RDF.iri(reservation_iri)}
    ]

  defp nonnegative_map?(value),
    do:
      is_map(value) and map_size(value) > 0 and
        Enum.all?(value, fn {_key, count} -> is_integer(count) and count >= 0 end)

  defp matching_price(raw, price) do
    if raw.provider == price.provider and raw.model == price.model,
      do: :ok,
      else: invalid(:wiki_measured_usage)
  end

  defp positive_revision(value) when is_integer(value) and value > 0, do: :ok
  defp positive_revision(_value), do: invalid(:record_wiki_model_usage)

  defp terminal_state(state) when state in @terminal_states, do: {:ok, state}
  defp terminal_state(_state), do: invalid(:wiki_usage_record)

  defp nonnegative(first, second) do
    if nonnegative_map?(first) and (is_nil(second) or nonnegative_map?(second)),
      do: :ok,
      else: invalid(:wiki_usage_record)
  end

  defp required_resources(keys, attributes) do
    if Enum.all?(keys, &(Contract.resource(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid(:wiki_usage_record)
  end

  defp bounded_text(value, maximum)
       when is_binary(value) and byte_size(value) >= 1 and byte_size(value) <= maximum,
       do: :ok

  defp bounded_text(_value, _maximum), do: invalid(:wiki_usage_record)

  defp required_texts(keys, attributes, maximum) do
    if Enum.all?(keys, fn key ->
         is_binary(attributes[key]) and byte_size(attributes[key]) in 1..maximum
       end),
       do: :ok,
       else: invalid(:wiki_measured_usage)
  end

  defp currency(value) when is_binary(value) do
    if Regex.match?(~r/^[A-Z]{3}$/, value), do: :ok, else: invalid(:wiki_usage_record)
  end

  defp currency(_value), do: invalid(:wiki_usage_record)
  defp local_work(value) when is_map(value), do: :ok
  defp local_work(_value), do: invalid(:wiki_usage_record)
  defp recorded_at(%DateTime{}), do: :ok
  defp recorded_at(_value), do: invalid(:wiki_usage_record)

  defp digest(value),
    do: if(Contract.digest?(value), do: :ok, else: invalid(:wiki_measured_usage))

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
