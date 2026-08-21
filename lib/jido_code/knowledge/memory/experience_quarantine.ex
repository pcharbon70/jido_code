defmodule JidoCode.Knowledge.Memory.ExperienceQuarantine do
  @moduledoc "Fail-closed quarantine checks for untrusted experience proposals."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.CandidateFactOrSummary
  alias JidoCode.Knowledge.Memory.ExperienceCase
  alias JidoCode.Knowledge.Memory.ExperienceSourceManifest
  alias JidoCode.Knowledge.ResourceIdentity

  @instruction ~r/(?:ignore (?:all |the )?(?:previous|prior) instructions|system prompt|you must|execute this|call the tool|override policy)/i
  @secret ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i
  @personal ~r/(?:\b\d{3}-\d{2}-\d{4}\b|\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b)/i
  @revision "1.0.0"

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec evaluate(
          ExperienceCase.t(),
          CandidateFactOrSummary.t(),
          ExperienceSourceManifest.t(),
          map()
        ) ::
          {:ok, map()} | {:quarantined, map()} | {:error, Error.t()}
  def evaluate(
        %ExperienceCase{} = experience,
        %CandidateFactOrSummary{} = summary,
        %ExperienceSourceManifest{} = manifest,
        context
      )
      when is_map(context) do
    with true <- summary.case_iri == experience.iri,
         true <- summary.source_manifest_iri == manifest.iri,
         true <- summary.source_manifest_digest == manifest.digest,
         :ok <- exact_context?(experience, manifest, context) do
      untrusted_text = Enum.join([summary.summary | summary.claims ++ summary.triggers], "\n")

      reasons =
        []
        |> add(:embedded_instruction, Regex.match?(@instruction, untrusted_text))
        |> add(:secret, Regex.match?(@secret, untrusted_text))
        |> add(:personal_data, Regex.match?(@personal, untrusted_text))
        |> add(:cross_scope_reference, cross_scope?(summary.related_iris, context))
        |> add(:unsupported_claim, unsupported?(summary.claims, context))
        |> add(
          :future_leakage,
          DateTime.compare(summary.recorded_at, manifest.effective_at) == :gt
        )
        |> add(:suspicious_trigger, suspicious_triggers?(summary.triggers))
        |> add(:missing_evidence, manifest.source_evidence_iris == [])
        |> Enum.reverse()

      report = report(experience, summary, manifest, reasons, context)
      if reasons == [], do: {:ok, report}, else: {:quarantined, report}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def evaluate(_experience, _summary, _manifest, _context), do: invalid()

  @spec statements(map()) :: [tuple()]
  def statements(report) when is_map(report) do
    jf = "https://jido.run/ontology/factory#"
    rdf_type = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

    [
      {report.iri, rdf_type, RDF.iri(jf <> "ExperienceQuarantineReport")},
      {report.iri, jf <> "about", RDF.iri(report.case_iri)},
      {report.iri, jf <> "candidateSummary", RDF.iri(report.summary_iri)},
      {report.iri, jf <> "sourceManifestDigest",
       RDF.XSD.String.new(report.source_manifest_digest)},
      {report.iri, jf <> "evaluatedBy", RDF.iri(report.evaluator_iri)},
      {report.iri, jf <> "quarantineClear", RDF.XSD.Boolean.new(report.clear?)},
      {report.iri, jf <> "reportDigest", RDF.XSD.String.new(report.digest)}
    ] ++
      Enum.map(report.reasons, fn reason ->
        {report.iri, jf <> "quarantineReason", RDF.XSD.String.new(to_string(reason))}
      end)
  end

  defp exact_context?(experience, manifest, context) do
    if context[:repository_iri] == experience.repository_iri and
         context[:repository_scope_iri] == experience.repository_scope_iri and
         context[:effective_at] == manifest.effective_at and
         is_list(context[:supported_claims]) and is_list(context[:allowed_related_iris]) and
         ResourceIdentity.validate(context[:evaluator_iri]) == :ok do
      :ok
    else
      invalid()
    end
  end

  defp cross_scope?(values, context),
    do: not MapSet.subset?(MapSet.new(values), MapSet.new(context.allowed_related_iris))

  defp unsupported?(claims, context),
    do: not MapSet.subset?(MapSet.new(claims), MapSet.new(context.supported_claims))

  defp suspicious_triggers?(values) do
    normalized = Enum.map(values, &String.downcase/1)
    length(normalized) >= 3 and length(Enum.uniq(normalized)) * 2 <= length(normalized)
  end

  defp report(experience, summary, manifest, reasons, context) do
    digest =
      digest(
        {@revision, experience.iri, summary.iri, manifest.digest, reasons, context.evaluator_iri}
      )

    {:ok, iri} = ResourceIdentity.deterministic(:experience_quarantine_report, digest)

    %{
      iri: iri,
      revision: @revision,
      case_iri: experience.iri,
      summary_iri: summary.iri,
      source_manifest_digest: manifest.digest,
      evaluator_iri: context.evaluator_iri,
      reasons: reasons,
      clear?: reasons == [],
      digest: digest
    }
  end

  defp add(values, _reason, false), do: values
  defp add(values, reason, true), do: [reason | values]

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid, do: {:error, Error.new(:unauthorized, :experience_quarantine)}
end
