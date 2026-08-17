defmodule JidoCode.Factory.Tool.Proposal do
  @moduledoc "Transient normalized tool proposal whose durable projection contains digests only."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Catalog
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge

  @derive {Inspect,
           only: [
             :iri,
             :source,
             :invocation_iri,
             :tool_name,
             :tool_version,
             :classification,
             :proposal_digest,
             :arguments_digest
           ]}
  @enforce_keys [
    :iri,
    :source,
    :invocation_iri,
    :tool_name,
    :tool_version,
    :classification,
    :input_refs,
    :arguments,
    :proposal_digest,
    :arguments_digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @classifications ~w[public internal confidential restricted]a

  @spec from_directive(String.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def from_directive(invocation_iri, directive) when is_map(directive) do
    if MapSet.new(Map.keys(directive)) ==
         MapSet.new([:tool_name, :tool_version, :classification, :input_refs, :arguments]) do
      build(:jido_directive, invocation_iri, directive)
    else
      invalid()
    end
  end

  def from_directive(_invocation_iri, _directive), do: invalid()

  @spec from_model_call(String.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def from_model_call(invocation_iri, model_call) when is_map(model_call) do
    expected = MapSet.new(~w[name version classification input_refs arguments])

    if MapSet.new(Map.keys(model_call)) == expected do
      build(:model_tool_call, invocation_iri, %{
        tool_name: model_call["name"],
        tool_version: model_call["version"],
        classification: classification(model_call["classification"]),
        input_refs: model_call["input_refs"],
        arguments: model_call["arguments"]
      })
    else
      invalid()
    end
  end

  def from_model_call(_invocation_iri, _model_call), do: invalid()

  @spec persistent_attributes(t()) :: map()
  def persistent_attributes(%__MODULE__{} = proposal) do
    %{
      invocation_iri: proposal.invocation_iri,
      proposed_command: proposal.tool_name,
      proposal_digest: proposal.proposal_digest,
      arguments_digest: proposal.arguments_digest
    }
  end

  defp build(source, invocation_iri, attributes) do
    with :ok <- Knowledge.validate_resource_identity(invocation_iri),
         {:ok, %Definition{} = definition} <-
           Catalog.fetch(attributes.tool_name, attributes.tool_version),
         classification when classification in @classifications <- attributes[:classification],
         :ok <- resources(attributes[:input_refs]),
         arguments when is_map(arguments) <- attributes[:arguments],
         {:ok, arguments} <- normalize_arguments(arguments, definition.input_schema.properties),
         true <- bounded?(arguments, 32_768),
         arguments_digest <- digest(arguments),
         proposal_digest <-
           digest({
             invocation_iri,
             attributes.tool_name,
             attributes.tool_version,
             classification,
             Enum.sort(attributes.input_refs),
             arguments_digest
           }),
         {:ok, %{iri: iri}} <-
           Knowledge.action_proposal(%{
             invocation_iri: invocation_iri,
             proposed_command: attributes.tool_name,
             proposal_digest: proposal_digest,
             arguments_digest: arguments_digest
           }) do
      {:ok,
       %__MODULE__{
         iri: iri,
         source: source,
         invocation_iri: invocation_iri,
         tool_name: attributes.tool_name,
         tool_version: attributes.tool_version,
         classification: classification,
         input_refs: Enum.sort(attributes.input_refs),
         arguments: arguments,
         proposal_digest: proposal_digest,
         arguments_digest: arguments_digest
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  defp resources(values) when is_list(values) and values != [] and length(values) <= 32 do
    if Enum.all?(values, &(Knowledge.validate_resource_identity(&1) == :ok)) and
         length(values) == length(Enum.uniq(values)),
       do: :ok,
       else: :error
  end

  defp resources(_values), do: :error

  defp normalize_arguments(arguments, properties) do
    known = Map.new(Map.keys(properties), &{Atom.to_string(&1), &1})

    Enum.reduce_while(arguments, {:ok, %{}}, fn
      {key, value}, {:ok, normalized} when is_atom(key) ->
        if Map.has_key?(properties, key) and not Map.has_key?(normalized, key),
          do: {:cont, {:ok, Map.put(normalized, key, value)}},
          else: {:halt, :error}

      {key, value}, {:ok, normalized} when is_binary(key) ->
        case Map.fetch(known, key) do
          {:ok, atom_key} ->
            if Map.has_key?(normalized, atom_key),
              do: {:halt, :error},
              else: {:cont, {:ok, Map.put(normalized, atom_key, value)}}

          :error ->
            {:halt, :error}
        end

      _entry, _accumulator ->
        {:halt, :error}
    end)
  end

  defp classification("public"), do: :public
  defp classification("internal"), do: :internal
  defp classification("confidential"), do: :confidential
  defp classification("restricted"), do: :restricted
  defp classification(_classification), do: :invalid

  defp digest(value) do
    :crypto.hash(:sha256, :erlang.term_to_binary(value, [:deterministic]))
    |> Base.encode16(case: :lower)
  end

  defp bounded?(value, maximum),
    do: byte_size(:erlang.term_to_binary(value, [:deterministic])) <= maximum

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :action_proposal)}
end
