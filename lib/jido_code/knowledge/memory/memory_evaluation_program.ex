defmodule JidoCode.Knowledge.Memory.MemoryEvaluationProgram do
  @moduledoc "Reproducible memory ablation, harm measurement, and fail-closed release acceptance."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @ablations ~w[
    no_memory recent_history all_eligible_history summaries lexical_retrieval dense_retrieval
    graph_retrieval cases procedures hybrid_retrieval oracle_retrieval stale_or_poisoned_memory
  ]a
  @retrieval_metrics ~w[
    precision recall ranking_quality source_completeness authorization_denial_correctness
    invalidation_latency_ms retrieval_cost
  ]a
  @outcome_metrics ~w[
    task_success time_to_accepted_patch review_burden regression_rate recovery_quality token_cost
    operator_intervention
  ]a
  @harm_metrics ~w[
    negative_transfer procedure_misuse invalidation_misses hallucinated_memory
    poisoned_memory_uptake scope_leakage erasure_misses temporal_leakage
  ]a
  @zero_tolerance ~w[
    cross_scope_leaks secret_leaks accounting_drift missing_sources temporal_violations
    permit_bypasses stale_claim_acceptance erasure_failures future_patch_leakage
    critical_false_acceptance
  ]a
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @jf "https://jido.run/ontology/factory#"

  def revision, do: @revision
  def ablations, do: @ablations
  def retrieval_metrics, do: @retrieval_metrics
  def outcome_metrics, do: @outcome_metrics
  def harm_metrics, do: @harm_metrics
  def zero_tolerance_metrics, do: @zero_tolerance

  def evaluate(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:manifest_iri]),
         :ok <- ResourceIdentity.validate(attributes[:evaluator_iri]),
         {:ok, ablations} <- validate_ablations(attributes[:ablations]),
         {:ok, zero_tolerance} <- exact_metrics(attributes[:zero_tolerance], @zero_tolerance),
         {:ok, products} <- validate_products(attributes[:launch_products]),
         %DateTime{} = recorded_at <- attributes[:recorded_at],
         {:ok, iri} <- identity(attributes, ablations, zero_tolerance, products) do
      reasons = rejection_reasons(zero_tolerance, products)
      accepted? = reasons == []

      report = %{
        iri: iri,
        revision: @revision,
        manifest_iri: attributes.manifest_iri,
        evaluator_iri: attributes.evaluator_iri,
        ablations: ablations,
        zero_tolerance: zero_tolerance,
        launch_products: products,
        accepted?: accepted?,
        decision: if(accepted?, do: :accepted, else: :blocked),
        rejection_reasons: reasons,
        recorded_at: DateTime.truncate(recorded_at, :microsecond),
        evaluation_digest: digest({ablations, zero_tolerance, products}),
        all_ablations_complete?: true,
        metric_contract_exact?: true,
        immediate_disable_paths_complete?: Enum.all?(products, &disable_path?/1)
      }

      {:ok, report}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def evaluate(_attributes), do: invalid()

  def statements(report) when is_map(report) do
    [
      {report.iri, @rdf_type, RDF.iri(@jf <> "MemoryEvaluationRun")},
      {report.iri, @jf <> "version", RDF.XSD.String.new(report.revision)},
      {report.iri, @jf <> "datasetManifest", RDF.iri(report.manifest_iri)},
      {report.iri, @jf <> "evaluator", RDF.iri(report.evaluator_iri)},
      {report.iri, @jf <> "evaluationDigest", RDF.XSD.String.new(report.evaluation_digest)},
      {report.iri, @jf <> "releaseDecision", concept(report.decision)},
      {report.iri, @jf <> "accepted", RDF.XSD.Boolean.new(report.accepted?)},
      {report.iri, @jf <> "recordedAt", RDF.XSD.DateTime.new(report.recorded_at)}
    ] ++
      Enum.map(@ablations, &{report.iri, @jf <> "evaluatedAblation", concept(&1)}) ++
      Enum.map(report.rejection_reasons, fn reason ->
        {report.iri, @jf <> "rejectionReason", concept(reason)}
      end) ++
      Enum.map(report.launch_products, fn product ->
        {report.iri, @jf <> "launchProduct", concept(product.product)}
      end)
  end

  def statements(_report), do: []

  defp validate_ablations(values) when is_map(values) do
    if Enum.sort(Map.keys(values)) == Enum.sort(@ablations) do
      values
      |> Enum.reduce_while({:ok, %{}}, fn {ablation, metrics}, {:ok, accepted} ->
        with true <- is_map(metrics),
             {:ok, retrieval} <- exact_metrics(metrics[:retrieval], @retrieval_metrics),
             {:ok, outcomes} <- exact_metrics(metrics[:outcomes], @outcome_metrics),
             {:ok, harms} <- exact_metrics(metrics[:harms], @harm_metrics) do
          normalized = %{retrieval: retrieval, outcomes: outcomes, harms: harms}
          {:cont, {:ok, Map.put(accepted, ablation, normalized)}}
        else
          _invalid -> {:halt, :error}
        end
      end)
      |> case do
        {:ok, normalized} -> {:ok, normalized}
        _error -> :error
      end
    else
      :error
    end
  end

  defp validate_ablations(_values), do: :error

  defp exact_metrics(metrics, keys) when is_map(metrics) do
    if Enum.sort(Map.keys(metrics)) == Enum.sort(keys) and
         Enum.all?(metrics, fn {_key, value} -> finite_non_negative?(value) end),
       do: {:ok, Map.new(metrics)},
       else: :error
  end

  defp exact_metrics(_metrics, _keys), do: :error

  defp validate_products(products) when is_list(products) and products != [] do
    normalized = Enum.sort_by(products, & &1[:product])

    if Enum.all?(normalized, &valid_product?/1) and
         length(Enum.uniq_by(normalized, & &1.product)) == length(normalized),
       do: {:ok, normalized},
       else: :error
  end

  defp validate_products(_products), do: :error

  defp valid_product?(product) when is_map(product) do
    is_atom(product[:product]) and
      product[:ablation] in (@ablations -- [:no_memory, :oracle_retrieval]) and
      finite_number?(product[:effect_size]) and finite_number?(product[:confidence_low]) and
      finite_non_negative?(product[:p_value]) and product.p_value <= 1.0 and
      is_integer(product[:sample_size]) and product.sample_size >= 30 and disable_path?(product)
  end

  defp valid_product?(_product), do: false

  defp disable_path?(product) do
    case product[:disable_path] do
      %{
        command: "DisableMemoryProduct",
        owner_iri: owner_iri,
        maximum_latency_seconds: latency
      }
      when is_integer(latency) and latency > 0 and latency <= 300 ->
        ResourceIdentity.validate(owner_iri) == :ok

      _invalid ->
        false
    end
  end

  defp rejection_reasons(zero_tolerance, products) do
    zero_failures =
      zero_tolerance
      |> Enum.filter(fn {_metric, value} -> value != 0 and value != 0.0 end)
      |> Enum.map(fn {metric, _value} -> metric end)

    supported? =
      Enum.any?(products, fn product ->
        product.effect_size > 0 and product.confidence_low > 0 and product.p_value <= 0.05 and
          product.sample_size >= 30
      end)

    disable_paths? = Enum.all?(products, &disable_path?/1)

    zero_failures ++
      if(supported?, do: [], else: [:no_statistically_supported_benefit]) ++
      if(disable_paths?, do: [], else: [:disable_path_incomplete])
  end

  defp identity(attributes, ablations, zero_tolerance, products) do
    ResourceIdentity.deterministic(
      :memory_evaluation_run,
      :erlang.term_to_binary(
        {attributes.manifest_iri, attributes.evaluator_iri, ablations, zero_tolerance, products,
         attributes.recorded_at},
        [:deterministic]
      )
    )
  end

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp finite_non_negative?(value), do: finite_number?(value) and value >= 0
  defp finite_number?(value) when is_integer(value), do: true
  defp finite_number?(value) when is_float(value), do: value == value
  defp finite_number?(_value), do: false

  defp concept(value),
    do: RDF.iri("https://jido.run/ontology/concept/" <> Macro.camelize(to_string(value)))

  defp invalid, do: {:error, Error.new(:invalid_input, :memory_evaluation_program)}
end
