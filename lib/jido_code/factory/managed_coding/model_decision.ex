defmodule JidoCode.Factory.ManagedCoding.ModelDecision do
  @moduledoc "Strict, non-coercing union accepted from one managed coding model turn."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.TrustBoundary
  alias JidoCode.Factory.Model.Response

  @enforce_keys [:kind, :payload]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec parse(Response.t()) :: {:ok, t()} | {:error, AdapterError.t()}
  def parse(%Response{type: :final_answer, text: text, tool_calls: []}) when is_binary(text) do
    with {:ok, decoded} <- Jason.decode(text),
         true <- is_map(decoded),
         {:ok, decision} <- decision(decoded),
         :ok <- TrustBoundary.validate_payload(decision.payload) do
      {:ok, decision}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def parse(%Response{}), do: invalid()

  defp decision(%{"kind" => "tool_proposal", "tool" => tool} = value)
       when map_size(value) == 2 and is_map(tool) do
    expected = MapSet.new(~w[name version arguments classification input_refs])

    if MapSet.new(Map.keys(tool)) == expected and is_binary(tool["name"]) and
         is_binary(tool["version"]) and is_map(tool["arguments"]) and
         tool["classification"] in ~w[public internal confidential restricted] and
         is_list(tool["input_refs"]) do
      {:ok, %__MODULE__{kind: :tool_proposal, payload: atomized_tool(tool)}}
    else
      invalid()
    end
  end

  defp decision(
         %{"kind" => "completion_proposal", "summary" => summary, "claims" => claims} = value
       )
       when map_size(value) == 3 and is_binary(summary) and is_list(claims) do
    if byte_size(summary) <= 4_096 and length(claims) <= 32 and
         Enum.all?(claims, &(is_binary(&1) and byte_size(&1) <= 1_024)) do
      {:ok, %__MODULE__{kind: :completion_proposal, payload: %{summary: summary, claims: claims}}}
    else
      invalid()
    end
  end

  defp decision(%{"kind" => "clarification", "question" => question, "reason" => reason} = value)
       when map_size(value) == 3 and is_binary(question) and
              reason in ~w[missing_authority ambiguous_intent missing_input] do
    if byte_size(question) in 1..2_048,
      do:
        {:ok, %__MODULE__{kind: :clarification, payload: %{question: question, reason: reason}}},
      else: invalid()
  end

  defp decision(%{"kind" => "abstention", "reason" => reason} = value)
       when map_size(value) == 2 and is_binary(reason) do
    if byte_size(reason) in 1..2_048,
      do: {:ok, %__MODULE__{kind: :abstention, payload: %{reason: reason}}},
      else: invalid()
  end

  defp decision(_value), do: invalid()

  defp atomized_tool(tool) do
    %{
      name: tool["name"],
      version: tool["version"],
      arguments: tool["arguments"],
      classification: classification(tool["classification"]),
      input_refs: tool["input_refs"]
    }
  end

  defp classification("public"), do: :public
  defp classification("internal"), do: :internal
  defp classification("confidential"), do: :confidential
  defp classification("restricted"), do: :restricted
  defp invalid, do: {:error, AdapterError.new(:corrupt, :managed_coding_model_decision)}
end
