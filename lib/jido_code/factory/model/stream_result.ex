defmodule JidoCode.Factory.Model.StreamResult do
  @moduledoc "Exactly one bounded terminal result committed by the stream coordinator."

  alias JidoCode.Factory.Model.Request

  @derive {Inspect, only: [:status, :finish_reason, :diagnostic]}
  @enforce_keys [
    :status,
    :invocation_iri,
    :text,
    :tool_calls,
    :usage,
    :finish_reason,
    :diagnostic
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @statuses ~w[completed cancelled timed_out failed]a

  @spec new(map()) :: {:ok, t()} | :error
  def new(attributes) when is_map(attributes) do
    with status when status in @statuses <- attributes[:status],
         invocation_iri when is_binary(invocation_iri) <- attributes[:invocation_iri],
         text when is_binary(text) <- attributes[:text],
         true <- byte_size(text) <= 262_144,
         tool_calls when is_list(tool_calls) <- attributes[:tool_calls],
         true <- length(tool_calls) <= 64 and bounded?(tool_calls, 131_072),
         usage when is_map(usage) <- attributes[:usage],
         true <- bounded?(usage, 16_384),
         finish_reason when is_atom(finish_reason) or is_nil(finish_reason) <-
           attributes[:finish_reason],
         diagnostic when is_binary(diagnostic) <- attributes[:diagnostic],
         true <- byte_size(diagnostic) <= 1_024 do
      {:ok,
       struct!(__MODULE__, %{
         status: status,
         invocation_iri: invocation_iri,
         text: text,
         tool_calls: tool_calls,
         usage: usage,
         finish_reason: finish_reason,
         diagnostic: diagnostic
       })}
    else
      _invalid -> :error
    end
  rescue
    _error -> :error
  end

  def new(_attributes), do: :error

  @spec cancellation(Request.t(), atom()) :: t()
  def cancellation(%Request{} = request, reason) when reason in [:cancelled, :lease_lost] do
    status = if reason == :cancelled, do: :cancelled, else: :failed

    {:ok, result} =
      new(%{
        status: status,
        invocation_iri: request.invocation_iri,
        text: "",
        tool_calls: [],
        usage: %{},
        finish_reason: :cancelled,
        diagnostic: "stream=#{reason}"
      })

    result
  end

  @spec timeout(Request.t()) :: t()
  def timeout(%Request{} = request) do
    {:ok, result} =
      new(%{
        status: :timed_out,
        invocation_iri: request.invocation_iri,
        text: "",
        tool_calls: [],
        usage: %{},
        finish_reason: :incomplete,
        diagnostic: "stream=timed_out"
      })

    result
  end

  defp bounded?(value, maximum) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> byte_size()
    |> Kernel.<=(maximum)
  end
end
