defmodule JidoCode.Knowledge.Execution.InteractionProjection do
  @moduledoc "Authorized, bounded interaction views with chronology and redaction state."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.ResourceIdentity

  @queries ~w[interaction_session interaction_timeline]a
  @max_messages 100

  @spec build(QueryResult.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def build(%QueryResult{} = result, context) when is_map(context) do
    graph = context[:graph_iri]
    session = context[:session_iri]

    with true <- result.query_name in @queries,
         true <- result.query_version == QueryCatalog.execution_version(),
         {:ok, family} <- GraphRegistry.identify(graph),
         true <- family in [:repository_control, :run_attempt],
         :ok <- ResourceIdentity.validate(session),
         true <- Map.keys(result.graph_revisions) == [graph],
         revision when is_integer(revision) and revision > 0 <- result.graph_revisions[graph],
         {:ok, data} <- decode(result.query_name, result.data),
         true <- json_safe?(data) do
      {:ok,
       %{
         lens: Atom.to_string(result.query_name),
         session_iri: session,
         data: data,
         receipt: %{
           graph_iri: graph,
           graph_revision: revision,
           dataset_revision: result.dataset_revision,
           query_version: result.query_version,
           complete?: result.completeness.complete?,
           truncated?: result.truncated?,
           evaluated_at: DateTime.to_iso8601(result.evaluated_at)
         }
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:interaction_projection)
    end
  rescue
    _error -> invalid(:interaction_projection)
  end

  def build(_result, _context), do: invalid(:interaction_projection)

  defp decode(:interaction_session, rows) when is_list(rows) do
    values =
      rows
      |> Enum.map(fn row ->
        %{predicate: term_value(row["predicate"]), object: term_value(row["object"])}
      end)
      |> Enum.uniq()
      |> Enum.sort_by(&{&1.predicate, &1.object})

    {:ok, values}
  end

  defp decode(:interaction_timeline, rows) when is_list(rows) do
    messages =
      rows
      |> Enum.group_by(&term_value(&1["message"]))
      |> Enum.reject(fn {message, _rows} -> is_nil(message) end)
      |> Enum.map(fn {message, message_rows} ->
        classification = one_value(message_rows, "classification")

        %{
          message_iri: message,
          sequence: one_value(message_rows, "sequence"),
          sender_iri: one_value(message_rows, "sender"),
          audience_iris: values(message_rows, "audience"),
          reply_to_iri: one_value(message_rows, "reply"),
          classification_iri: classification,
          redacted?: String.ends_with?(classification || "", "Redacted"),
          intent_iri: one_value(message_rows, "intent"),
          content: one_value(message_rows, "content"),
          recorded_at: iso_value(message_rows, "recorded"),
          resulting_command_iri: one_value(message_rows, "command")
        }
      end)
      |> Enum.sort_by(&{&1.sequence, &1.message_iri})

    if length(messages) <= @max_messages and chronological?(messages),
      do: {:ok, %{messages: messages, count: length(messages)}},
      else: invalid(:interaction_projection_timeline)
  end

  defp decode(_query, _rows), do: invalid(:interaction_projection_data)

  defp chronological?(messages) do
    sequences = Enum.map(messages, & &1.sequence)

    Enum.all?(sequences, &is_integer/1) and sequences == Enum.sort(sequences) and
      length(sequences) == length(Enum.uniq(sequences))
  end

  defp one_value(rows, key) do
    case values(rows, key) do
      [value] -> value
      [] -> nil
      _many -> :ambiguous
    end
  end

  defp values(rows, key) do
    rows
    |> Enum.map(&term_value(&1[key]))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp iso_value(rows, key) do
    case Enum.map(rows, & &1[key]) |> Enum.reject(&is_nil/1) |> Enum.uniq() do
      [%{value: %DateTime{} = value}] -> DateTime.to_iso8601(value)
      [%{value: value}] -> value
      [value] -> value
      [] -> nil
      _many -> :ambiguous
    end
  end

  defp term_value(%{
         type: :literal,
         value: value,
         datatype: "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
       })
       when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer >= 0 -> integer
      _invalid -> value
    end
  end

  defp term_value(%{value: %DateTime{} = value}), do: DateTime.to_iso8601(value)
  defp term_value(%{value: value}), do: value
  defp term_value(nil), do: nil
  defp term_value(value), do: value

  defp json_safe?(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: true

  defp json_safe?(value) when is_atom(value), do: true
  defp json_safe?(value) when is_list(value), do: Enum.all?(value, &json_safe?/1)

  defp json_safe?(value) when is_map(value) and not is_struct(value),
    do: Enum.all?(value, fn {key, item} -> is_atom(key) and json_safe?(item) end)

  defp json_safe?(_value), do: false
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
