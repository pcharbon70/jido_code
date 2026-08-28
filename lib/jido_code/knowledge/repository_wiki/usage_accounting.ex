defmodule JidoCode.Knowledge.RepositoryWiki.UsageAccounting do
  @moduledoc "Terminal, idempotent repository wiki token and cost accounting."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.RepositoryWiki.Command
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.PriceProfile
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
         true <- raw.provider == price.provider and raw.model == price.model,
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
      _invalid -> invalid(:wiki_measured_usage)
    end
  end

  def measured(_raw, _price, _attributes), do: invalid(:wiki_measured_usage)

  @spec reconcile(Reservation.t(), map(), map()) ::
          {:ok, %{reservation: Reservation.t(), usage: map()}}
          | {:duplicate, map()}
          | {:error, atom()}
  def reconcile(%Reservation{} = reservation, usage, context)
      when is_map(usage) and is_map(context) do
    with true <- usage.reservation_iri == reservation.iri,
         true <- usage.attempt_iri == reservation.attempt_iri,
         true <- usage.invocation_iri == reservation.invocation_iri,
         true <- usage.price_revision == reservation.price_revision,
         true <- usage.accounting_fence == context[:accounting_fence],
         :none <- existing(usage, context),
         {:ok, transitioned} <-
           Reservation.transition(reservation, reservation_state(usage), usage.recorded_at) do
      {:ok, %{reservation: transitioned, usage: usage}}
    else
      {:duplicate, existing} -> {:duplicate, existing}
      false -> {:error, :mismatched_usage}
      {:error, reason} when is_atom(reason) -> {:error, reason}
      _invalid -> {:error, :invalid}
    end
  end

  def reconcile(_reservation, _usage, _context), do: {:error, :invalid}

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
         true <- is_integer(run_revision) and run_revision > 0,
         true <- is_integer(control_revision) and control_revision > 0,
         true <- usage.state in @terminal_states,
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
         state when state in @terminal_states <- attributes[:state],
         true <- nonnegative_map?(tokens),
         true <- nonnegative_map?(costs),
         true <- generation_mode != :deterministic_only or zero?(tokens, costs),
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
      _invalid -> invalid(:wiki_usage_record)
    end
  rescue
    _error -> invalid(:wiki_usage_record)
  end

  defp common(attributes) do
    resource_keys = ~w[repository_iri tenant_iri actor_iri attempt_iri edition_iri profile_iri]a

    with true <- Enum.all?(resource_keys, &(Contract.resource(attributes[&1]) == :ok)),
         :ok <- Contract.optional_resource(attributes[:reservation_iri]),
         :ok <- Contract.optional_resource(attributes[:invocation_iri]),
         true <- is_binary(attributes[:trigger]) and byte_size(attributes.trigger) in 1..128,
         true <-
           is_binary(attributes[:source_revision]) and
             byte_size(attributes.source_revision) in 1..512,
         true <-
           is_binary(attributes[:currency]) and Regex.match?(~r/^[A-Z]{3}$/, attributes.currency),
         true <- is_map(attributes[:local_work]),
         true <- match?(%DateTime{}, attributes[:recorded_at]) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_usage_record)
    end
  end

  defp measured_usage(raw) do
    with true <- nonnegative_map?(Map.take(raw, [:input, :output, :cached, :reasoning])),
         true <-
           Enum.all?(
             [:provider, :model, :region],
             &(is_binary(raw[&1]) and byte_size(raw[&1]) in 1..128)
           ),
         :ok <- Contract.resource(raw[:provider_request_iri]),
         true <- Contract.digest?(raw[:raw_evidence_digest]) do
      :ok
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_measured_usage)
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

  defp zero?(tokens, costs),
    do:
      Enum.all?(tokens, fn {_key, value} -> value == 0 end) and
        Enum.all?(costs, fn {_key, value} -> value == 0 end)

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
