defmodule JidoCode.Runtime.JidoHarness.CodexEventMapper do
  @moduledoc "Bounded, secret-aware normalization of the pinned Codex JSONL protocol."

  alias JidoCode.Factory.AdapterError

  @max_event_bytes 65_536
  @allowed_types ~w[thread.started turn.started item.started item.updated item.completed turn.completed error]
  @result_classes ~w[candidate clarification checkpoint failure]a

  @spec normalize([map()], DateTime.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def normalize(events, %DateTime{} = observed_at)
      when is_list(events) and length(events) <= 100 do
    with :ok <- ordered_once(events) do
      Enum.reduce_while(events, {:ok, initial()}, fn event, {:ok, accumulator} ->
        with {:ok, normalized} <- normalize_event(event, observed_at),
             {:ok, merged} <- merge(accumulator, normalized) do
          {:cont, {:ok, merged}}
        else
          {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
        end
      end)
    end
  rescue
    _error -> invalid(:codex_jsonl_event)
  end

  def normalize(_events, _observed_at), do: invalid(:codex_jsonl_event)

  defp initial, do: %{observations: [], usage: %{}, result: nil, failed?: false}

  defp normalize_event(%{sequence: sequence, type: :stdout, data: data}, observed_at)
       when is_integer(sequence) and sequence > 0 and is_binary(data) and
              byte_size(data) in 1..@max_event_bytes do
    with false <- secret?(data),
         {:ok, decoded} <- Jason.decode(String.trim(data)),
         type when type in @allowed_types <- decoded["type"],
         {:ok, result} <- result(decoded),
         {:ok, usage} <- usage(decoded),
         digest <- digest(decoded) do
      {:ok,
       %{
         observations: [observation(sequence, observation_type(type), observed_at, digest)],
         usage: usage,
         result: result,
         failed?: type == "error"
       }}
    else
      _invalid -> invalid(:codex_jsonl_event)
    end
  end

  defp normalize_event(%{sequence: sequence, type: type, data: data}, observed_at)
       when is_integer(sequence) and sequence > 0 and type in [:stderr, :failed] do
    with true <- bounded_nonsecret?(data) do
      {:ok,
       %{
         observations: [observation(sequence, :failed, observed_at, digest(data))],
         usage: %{},
         result: nil,
         failed?: true
       }}
    else
      _invalid -> invalid(:codex_jsonl_event)
    end
  end

  defp normalize_event(%{sequence: sequence, type: :exited, data: data}, observed_at)
       when is_integer(sequence) and sequence > 0 do
    with true <- bounded_nonsecret?(data) do
      {:ok,
       %{
         observations: [observation(sequence, :completed, observed_at, digest(data))],
         usage: %{},
         result: nil,
         failed?: false
       }}
    else
      _invalid -> invalid(:codex_jsonl_event)
    end
  end

  defp normalize_event(_event, _observed_at), do: invalid(:codex_jsonl_event)

  defp result(%{
         "type" => "item.completed",
         "item" => %{"type" => "agent_message", "text" => text}
       })
       when is_binary(text) and byte_size(text) in 1..16_384 do
    with false <- secret?(text),
         {:ok, decoded} <- Jason.decode(text),
         classification when is_binary(classification) <- decoded["classification"],
         classification when classification in @result_classes <- result_class(classification),
         summary when is_binary(summary) and byte_size(summary) in 1..8_192 <- decoded["summary"],
         false <- secret?(summary),
         true <- Map.keys(decoded) |> Enum.sort() == ["classification", "summary"] do
      {:ok, %{classification: classification, summary_digest: digest(summary)}}
    else
      _invalid -> invalid(:codex_final_output)
    end
  rescue
    ArgumentError -> invalid(:codex_final_output)
  end

  defp result(_decoded), do: {:ok, nil}

  defp usage(%{"type" => "turn.completed", "usage" => usage}) when is_map(usage) do
    normalized =
      Map.take(usage, ["input_tokens", "cached_input_tokens", "output_tokens"])
      |> Enum.reduce_while(%{}, fn
        {key, value}, accumulator
        when is_integer(value) and value >= 0 and value <= 1_000_000_000 ->
          case usage_key(key) do
            nil -> {:halt, :error}
            atom -> {:cont, Map.put(accumulator, atom, value)}
          end

        _invalid, _accumulator ->
          {:halt, :error}
      end)

    if is_map(normalized), do: {:ok, normalized}, else: invalid(:codex_jsonl_usage)
  end

  defp usage(_decoded), do: {:ok, %{}}

  defp merge(%{result: existing}, %{result: incoming})
       when not is_nil(existing) and not is_nil(incoming),
       do: invalid(:codex_duplicate_final_output)

  defp merge(accumulator, normalized) do
    {:ok,
     %{
       observations: accumulator.observations ++ normalized.observations,
       usage: Map.merge(accumulator.usage, normalized.usage),
       result: normalized.result || accumulator.result,
       failed?: accumulator.failed? or normalized.failed?
     }}
  end

  defp ordered_once(events) do
    events
    |> Enum.reduce_while({:ok, nil}, fn
      %{sequence: sequence}, {:ok, nil} when is_integer(sequence) and sequence > 0 ->
        {:cont, {:ok, sequence}}

      %{sequence: sequence}, {:ok, previous}
      when is_integer(sequence) and sequence > previous ->
        {:cont, {:ok, sequence}}

      _event, _state ->
        {:halt, invalid(:codex_event_sequence)}
    end)
    |> case do
      {:ok, _sequence} -> :ok
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  end

  defp observation(sequence, type, occurred_at, payload_digest) do
    %{
      sequence: sequence,
      type: type,
      occurred_at: DateTime.truncate(occurred_at, :microsecond),
      payload_digest: payload_digest,
      tool_ref: nil
    }
  end

  defp observation_type("thread.started"), do: :started
  defp observation_type("turn.started"), do: :progress
  defp observation_type("item.started"), do: :provider_event
  defp observation_type("item.updated"), do: :provider_event
  defp observation_type("item.completed"), do: :provider_event
  defp observation_type("turn.completed"), do: :completed
  defp observation_type("error"), do: :failed

  defp result_class("candidate"), do: :candidate
  defp result_class("clarification"), do: :clarification
  defp result_class("checkpoint"), do: :checkpoint
  defp result_class("failure"), do: :failure
  defp result_class(_classification), do: nil

  defp usage_key("input_tokens"), do: :input_tokens
  defp usage_key("cached_input_tokens"), do: :cached_input_tokens
  defp usage_key("output_tokens"), do: :output_tokens
  defp usage_key(_key), do: nil

  defp bounded_nonsecret?(data) do
    is_binary(data) and byte_size(data) <= @max_event_bytes and not secret?(data)
  end

  defp secret?(value) when is_binary(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end

  defp secret?(_value), do: false

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
