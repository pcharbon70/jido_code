defmodule JidoCode.Knowledge.Validation.Quarantine do
  @moduledoc """
  Records only bounded, redacted validation reports in a security audit graph.

  Rejected source statements are never included in the audit payload and never
  become visible as domain assertions.
  """

  alias JidoCode.Knowledge.Commands.Graphs
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_collection "http://www.w3.org/ns/prov#Collection"
  @prov_had_member "http://www.w3.org/ns/prov#hadMember"
  @max_issues 100

  @spec record(map(), map(), keyword()) :: term()
  def record(report, attributes, options \\ [])

  def record(report, attributes, options)
      when is_map(report) and is_map(attributes) and is_list(options) do
    with :ok <- validate_report(report),
         :ok <- validate_attributes(attributes) do
      payload = report_quads(report)

      Graphs.create(
        :security_audit,
        %{period: attributes.period},
        payload,
        %{
          owner_scope: attributes.owner_scope,
          ontology_version: "https://jido.run/ontology/release/#{report.ontology_version}",
          creation_activity: attributes.activity,
          created_at: attributes.recorded_at
        },
        Keyword.put(options, :capability, :security_auditor)
      )
    end
  end

  def record(_report, _attributes, _options),
    do: {:error, Error.new(:invalid_input, :validation_quarantine)}

  defp validate_report(report) do
    required = [:report_iri, :ontology_version, :shape_version, :issues]

    cond do
      Map.get(report, :conforms?) != false ->
        invalid()

      not Enum.all?(required, &Map.has_key?(report, &1)) ->
        invalid()

      not is_binary(Map.get(report, :report_iri)) ->
        invalid()

      ResourceIdentity.validate(report.report_iri) != :ok ->
        invalid()

      not is_list(Map.get(report, :issues)) or length(report.issues) > @max_issues ->
        invalid()

      not valid_version?(report.ontology_version) or not valid_version?(report.shape_version) ->
        invalid()

      not Enum.all?(report.issues, &valid_issue?/1) ->
        invalid()

      true ->
        :ok
    end
  end

  defp valid_issue?(issue) do
    is_map(issue) and ResourceIdentity.validate(Map.get(issue, :result_iri)) == :ok and
      is_binary(Map.get(issue, :focus_node)) and RDF.IRI.valid?(issue.focus_node) and
      is_binary(Map.get(issue, :shape)) and RDF.IRI.valid?(issue.shape) and
      is_binary(Map.get(issue, :issue_code)) and byte_size(issue.issue_code) <= 64 and
      is_binary(Map.get(issue, :safe_message)) and byte_size(issue.safe_message) <= 160
  end

  defp validate_attributes(attributes) do
    with true <- is_binary(Map.get(attributes, :period)),
         true <- Regex.match?(~r/^\d{4}-(0[1-9]|1[0-2])$/, attributes.period),
         :ok <- ResourceIdentity.validate(Map.get(attributes, :owner_scope)),
         :ok <- ResourceIdentity.validate(Map.get(attributes, :activity)),
         true <- match?(%DateTime{}, Map.get(attributes, :recorded_at)) do
      :ok
    else
      _invalid -> invalid()
    end
  end

  defp report_quads(report) do
    report_subject = report.report_iri

    report_statements = [
      triple(report_subject, @rdf_type, iri(@jf <> "ValidationReport")),
      triple(report_subject, @rdf_type, iri(@prov_collection)),
      triple(report_subject, @jf <> "shapeVersion", RDF.literal(report.shape_version))
    ]

    Enum.reduce(report.issues, report_statements, fn issue, statements ->
      result = issue.result_iri

      result_statements = [
        triple(report_subject, @prov_had_member, iri(result)),
        triple(result, @rdf_type, iri(@jf <> "ValidationResult")),
        triple(result, @jf <> "focusNode", iri(issue.focus_node)),
        triple(result, @jf <> "resultShape", iri(issue.shape)),
        triple(result, @jf <> "issueCode", RDF.literal(issue.issue_code)),
        triple(result, @jf <> "severity", iri("https://jido.run/ontology/concept/Violation")),
        triple(result, @jf <> "safeMessage", RDF.literal(issue.safe_message))
      ]

      case issue.path do
        nil -> result_statements ++ statements
        path -> [triple(result, @jf <> "resultPath", iri(path)) | result_statements ++ statements]
      end
    end)
  end

  defp triple(subject, predicate, object), do: RDF.triple(subject, predicate, object)
  defp iri(value), do: RDF.iri(value)
  defp valid_version?(value), do: is_binary(value) and Regex.match?(~r/^\d+\.\d+\.\d+$/, value)
  defp invalid, do: {:error, Error.new(:invalid_input, :validation_quarantine)}
end
