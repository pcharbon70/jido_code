defmodule JidoCode.Factory.Model.Response do
  @moduledoc """
  Provider-neutral result from one buffered model interaction.

  Only bounded response projections cross the integration boundary. The raw
  provider response, prompt context, and provider-private metadata stay in the
  disposable adapter call.
  """

  alias JidoCode.Factory.AdapterError

  @derive {Inspect, only: [:type, :finish_reason]}
  @enforce_keys [
    :type,
    :text,
    :thinking,
    :tool_calls,
    :finish_reason,
    :usage,
    :call_metadata,
    :provenance
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @types ~w[final_answer tool_calls]a
  @finish_reasons ~w[
    stop length tool_calls content_filter error cancelled incomplete unknown
  ]a

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with type when type in @types <- attributes[:type],
         text when is_binary(text) <- attributes[:text],
         true <- byte_size(text) <= 262_144,
         thinking when is_binary(thinking) <- attributes[:thinking],
         true <- byte_size(thinking) <= 65_536,
         tool_calls when is_list(tool_calls) <- attributes[:tool_calls],
         true <- length(tool_calls) <= 64 and bounded?(tool_calls, 131_072),
         finish_reason when finish_reason in @finish_reasons or is_nil(finish_reason) <-
           attributes[:finish_reason],
         usage when is_map(usage) or is_nil(usage) <- attributes[:usage],
         true <- bounded?(usage, 16_384),
         call_metadata when is_map(call_metadata) <- attributes[:call_metadata],
         true <- bounded?(call_metadata, 32_768),
         provenance when is_map(provenance) <- attributes[:provenance],
         true <- bounded?(provenance, 16_384) do
      {:ok,
       %__MODULE__{
         type: type,
         text: text,
         thinking: thinking,
         tool_calls: tool_calls,
         finish_reason: finish_reason,
         usage: usage,
         call_metadata: call_metadata,
         provenance: provenance
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  defp bounded?(value, maximum) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> byte_size()
    |> Kernel.<=(maximum)
  end

  defp invalid, do: {:error, AdapterError.new(:corrupt, :model_response)}
end
