defmodule JidoCode.Factory.Tool.Request do
  @moduledoc "Bounded, fenced request passed to a tool adapter."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Knowledge

  @enforce_keys [
    :execution,
    :invocation_iri,
    :tool_iri,
    :tool_version,
    :sequence,
    :deadline,
    :expected_effect,
    :allowed_effects,
    :input_refs,
    :input_digests,
    :arguments,
    :output_bytes
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with %ExecutionRequest{} <- attributes[:execution],
         :ok <- resource(attributes[:invocation_iri]),
         :ok <- resource(attributes[:tool_iri]),
         version when is_binary(version) and byte_size(version) in 1..128 <-
           attributes[:tool_version],
         sequence when is_integer(sequence) and sequence >= 0 <- attributes[:sequence],
         %DateTime{} <- attributes[:deadline],
         effect when is_binary(effect) and byte_size(effect) in 1..256 <-
           attributes[:expected_effect],
         allowed when is_list(allowed) and length(allowed) <= 100 <- attributes[:allowed_effects],
         true <- effect in allowed,
         :ok <- resources(attributes[:input_refs]),
         :ok <- digests(attributes[:input_digests]),
         arguments when is_map(arguments) <- attributes[:arguments],
         true <- byte_size(:erlang.term_to_binary(arguments, [:deterministic])) <= 32_768,
         output when is_integer(output) and output in 1..1_048_576 <- attributes[:output_bytes] do
      {:ok, struct!(__MODULE__, Map.take(attributes, @enforce_keys))}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :tool_request)}
    end
  rescue
    _error -> {:error, AdapterError.new(:invalid_input, :tool_request)}
  end

  def new(_attributes), do: {:error, AdapterError.new(:invalid_input, :tool_request)}

  defp resources(values) when is_list(values) and length(values) <= 100 do
    if Enum.all?(values, &(Knowledge.validate_resource_identity(&1) == :ok)),
      do: :ok,
      else: :error
  end

  defp resources(_values), do: :error
  defp resource(value), do: Knowledge.validate_resource_identity(value)

  defp digests(values) when is_map(values) and map_size(values) <= 100 do
    if Enum.all?(values, fn {key, digest} ->
         is_binary(key) and byte_size(key) in 1..256 and
           is_binary(digest) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, digest)
       end),
       do: :ok,
       else: :error
  end

  defp digests(_values), do: :error
end
