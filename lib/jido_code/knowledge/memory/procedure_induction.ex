defmodule JidoCode.Knowledge.Memory.ProcedureInduction do
  @moduledoc "Multiple-case or explicit-expert proposal gate and hostile-content quarantine."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.ProcedureRevision
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @instruction ~r/(?:ignore (?:previous|prior) instructions|system prompt|execute this|call the tool|override policy)/i
  @secret ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_|sk-)[A-Za-z0-9_-]{20,}|(?:password|token|secret)\s*[=:]\s*\S+)/i
  @benchmark ~r/(?:benchmark answer|held[- ]out answer|golden patch|test fixture answer)/i

  def revision, do: @revision

  def propose(attributes, context) when is_map(attributes) and is_map(context) do
    supporting = attributes[:supporting_case_iris] || []
    expert = context[:expert_review_iri]

    with true <- length(Enum.uniq(supporting)) >= 2 or ResourceIdentity.validate(expert) == :ok,
         {:ok, procedure} <- ProcedureRevision.new(attributes) do
      {:ok, procedure}
    else
      _invalid -> {:error, Error.new(:unauthorized, :procedure_induction)}
    end
  end

  def propose(_, _), do: {:error, Error.new(:unauthorized, :procedure_induction)}

  def quarantine(%ProcedureRevision{} = procedure, context) when is_map(context) do
    text =
      Enum.join(
        [procedure.purpose | procedure.triggers ++ Enum.map(procedure.steps, & &1.instruction)],
        "\n"
      )

    reasons =
      []
      |> add(:embedded_instruction, Regex.match?(@instruction, text))
      |> add(:secret, Regex.match?(@secret, text))
      |> add(:benchmark_leakage, Regex.match?(@benchmark, text))
      |> add(:over_generalization, context[:scope_exact?] != true)
      |> add(
        :missing_preconditions,
        map_size(procedure.applicability) < 3 or procedure.stop_conditions == []
      )
      |> add(:duplicate_procedure, procedure.iri in (context[:existing_procedure_iris] || []))
      |> Enum.reverse()

    {:ok, iri} =
      ResourceIdentity.deterministic(
        :procedure_quarantine_report,
        :erlang.term_to_binary({procedure.iri, reasons}, [:deterministic])
      )

    report = %{
      iri: iri,
      revision: @revision,
      procedure_iri: procedure.iri,
      reasons: reasons,
      clear?: reasons == [],
      evaluator_iri: context[:evaluator_iri]
    }

    if report.clear?, do: {:ok, report}, else: {:quarantined, report}
  end

  def quarantine(_, _), do: {:error, Error.new(:invalid_input, :procedure_quarantine)}

  defp add(values, _reason, false), do: values
  defp add(values, reason, true), do: [reason | values]
end
