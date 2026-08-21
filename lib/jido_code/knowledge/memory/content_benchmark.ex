defmodule JidoCode.Knowledge.Memory.ContentBenchmark do
  @moduledoc "Pinned Phase 6 benchmark measurement and signed storage decision."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.Guardrails
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @latencies ~w[capture query backup restore rebuild]a

  def revision, do: @revision

  def measure(baseline, measured, integrity) when is_map(baseline) and is_map(measured) do
    with true <- Enum.all?(@latencies, &positive_number?(baseline[&1])),
         true <- Enum.all?(@latencies, &non_negative_number?(measured[&1])),
         true <- positive_number?(baseline[:storage_bytes]),
         true <- non_negative_number?(measured[:storage_bytes]),
         true <- integrity_counts?(integrity) do
      ratios =
        Map.new(@latencies, fn key ->
          {String.to_atom("#{key}_latency_ratio"), measured[key] / baseline[key]}
        end)

      {:ok,
       Map.merge(ratios, %{
         storage_amplification_ratio: measured.storage_bytes / baseline.storage_bytes,
         integrity_failures: integrity.integrity_failures,
         orphaned_objects: integrity.orphaned_objects,
         unerased_objects: integrity.unerased_objects
       })}
    else
      _invalid -> {:error, Error.new(:invalid_input, :content_benchmark_measurement)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :content_benchmark_measurement)}
  end

  def measure(_baseline, _measured, _integrity),
    do: {:error, Error.new(:invalid_input, :content_benchmark_measurement)}

  def decide(metrics, signer) when is_map(metrics) and is_function(signer, 1) do
    decision = Guardrails.storage_decision(metrics)
    thresholds = Guardrails.benchmark_thresholds()
    corpus_digest = Guardrails.benchmark_corpus_digest()
    metrics_digest = digest_term(metrics)
    material = Enum.join([@revision, corpus_digest, metrics_digest, to_string(decision)], "\n")

    with {:ok, iri} <- ResourceIdentity.deterministic(:content_benchmark_decision, material),
         signature when is_binary(signature) and byte_size(signature) >= 32 <- signer.(material) do
      {:ok,
       %{
         iri: iri,
         revision: @revision,
         decision: decision,
         corpus_digest: corpus_digest,
         metrics: metrics,
         metrics_digest: metrics_digest,
         thresholds: thresholds,
         signature: Base.encode64(signature),
         signed_material: material
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :content_benchmark_decision)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :content_benchmark_decision)}
  end

  def decide(_metrics, _signer),
    do: {:error, Error.new(:invalid_input, :content_benchmark_decision)}

  def verify(decision, verifier) when is_map(decision) and is_function(verifier, 2) do
    with signature when is_binary(signature) <- Base.decode64!(decision[:signature]),
         true <- verifier.(decision[:signed_material], signature),
         true <- decision[:metrics_digest] == digest_term(decision[:metrics]),
         true <- decision[:corpus_digest] == Guardrails.benchmark_corpus_digest(),
         true <- decision[:thresholds] == Guardrails.benchmark_thresholds(),
         true <- decision[:decision] == Guardrails.storage_decision(decision[:metrics]) do
      :ok
    else
      _invalid -> {:error, Error.new(:unauthorized, :content_benchmark_signature)}
    end
  rescue
    _error -> {:error, Error.new(:unauthorized, :content_benchmark_signature)}
  end

  def verify(_decision, _verifier),
    do: {:error, Error.new(:unauthorized, :content_benchmark_signature)}

  defp integrity_counts?(value) when is_map(value) do
    Enum.all?(~w[integrity_failures orphaned_objects unerased_objects]a, fn key ->
      count = value[key]
      is_integer(count) and count >= 0
    end)
  end

  defp integrity_counts?(_value), do: false
  defp positive_number?(value), do: is_number(value) and value > 0
  defp non_negative_number?(value), do: is_number(value) and value >= 0

  defp digest_term(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
