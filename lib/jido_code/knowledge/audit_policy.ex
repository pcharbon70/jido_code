defmodule JidoCode.Knowledge.AuditPolicy do
  @moduledoc """
  Append-only partition and disclosure policy for semantic command audit RDF.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry

  @forbidden_predicate ~r/(?:secret|credentialvalue|password|privatekey|token|prompt|sourcebody|stacktrace|sparql)$/i
  @forbidden_literal ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_|sk-)[A-Za-z0-9_-]{16,}|(?:password|token|secret)\s*[=:]\s*\S+)/i
  @max_literal_bytes 1_024

  @spec graph_iri(DateTime.t()) :: {:ok, String.t()} | {:error, Error.t()}
  def graph_iri(%DateTime{} = time) do
    period = time |> DateTime.to_date() |> Date.to_iso8601() |> binary_part(0, 7)
    GraphRegistry.graph_iri(:security_audit, %{period: period})
  end

  def graph_iri(_time), do: {:error, Error.new(:invalid_input, :audit_period)}

  @spec validate([RDF.Quad.t()]) :: :ok | {:error, Error.t()}
  def validate(quads) when is_list(quads) do
    if Enum.all?(quads, &safe_quad?/1),
      do: :ok,
      else: {:error, Error.new(:invalid_input, :audit_payload)}
  end

  def validate(_quads), do: {:error, Error.new(:invalid_input, :audit_payload)}

  @spec read_allowed?(atom()) :: boolean()
  def read_allowed?(capability), do: capability in [:security, :administrative]

  defp safe_quad?({_subject, %RDF.IRI{value: predicate}, object, _graph}) do
    local = predicate |> String.split(["#", "/"]) |> List.last()
    lexical = if match?(%RDF.Literal{}, object), do: RDF.Literal.lexical(object), else: nil

    not Regex.match?(@forbidden_predicate, local) and
      (is_nil(lexical) or
         (byte_size(lexical) <= @max_literal_bytes and
            not Regex.match?(@forbidden_literal, lexical)))
  end

  defp safe_quad?(_quad), do: false
end
