defmodule JidoCode.Security.Redactor do
  @moduledoc """
  Fail-closed sanitizer for product, diagnostic, telemetry, and export values.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Security.DataPolicy
  alias JidoCode.Security.RedactionReceipt

  @version "1.0.0"
  @redacted "[REDACTED]"
  @max_depth 6
  @max_entries 200
  @max_string_bytes 8_192

  @secret_patterns [
    ~r/-----BEGIN [A-Z ]*PRIVATE KEY-----/,
    ~r/\bBearer\s+[A-Za-z0-9._~+\/-]+=*\b/i,
    ~r/\b(?:ghp|github_pat|sk|xox[baprs])[-_][_A-Za-z0-9-]{12,}\b/,
    ~r|https?://[^/@\s:]+:[^/@\s]+@|,
    ~r{/(?:home|Users)/[^/\s]+/}
  ]

  @spec sanitize(term()) :: {:ok, term(), RedactionReceipt.t()} | {:error, Error.t()}
  def sanitize(value) do
    with {:ok, sanitized, counts} <- sanitize(value, 0, %{checked: 0, redacted: 0}) do
      {:ok, sanitized,
       %RedactionReceipt{
         classification_version: @version,
         redacted_count: counts.redacted,
         checked_count: counts.checked,
         outcome: if(counts.redacted > 0, do: :redacted, else: :clean)
       }}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :redaction)}
  end

  @spec reject_sensitive(term()) :: :ok | {:error, Error.t()}
  def reject_sensitive(value) do
    case sanitize(value) do
      {:ok, _sanitized, %RedactionReceipt{redacted_count: 0}} -> :ok
      {:ok, _sanitized, _receipt} -> {:error, Error.new(:invalid_input, :sensitive_input)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp sanitize(_value, depth, _counts) when depth > @max_depth,
    do: {:error, Error.new(:invalid_input, :redaction_depth)}

  defp sanitize(value, _depth, counts)
       when is_nil(value) or is_boolean(value) or is_number(value),
       do: {:ok, value, checked(counts)}

  defp sanitize(value, _depth, counts) when is_binary(value) do
    if byte_size(value) <= @max_string_bytes do
      counts = checked(counts)

      if sensitive_string?(value),
        do: {:ok, @redacted, redacted(counts)},
        else: {:ok, value, counts}
    else
      {:error, Error.new(:invalid_input, :redaction_size)}
    end
  end

  defp sanitize(value, depth, counts) when is_list(value) and length(value) <= @max_entries do
    Enum.reduce_while(value, {:ok, [], counts}, fn item, {:ok, acc, current} ->
      case sanitize(item, depth + 1, current) do
        {:ok, sanitized, next} -> {:cont, {:ok, [sanitized | acc], next}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, items, next} -> {:ok, Enum.reverse(items), next}
      error -> error
    end
  end

  defp sanitize(value, depth, counts)
       when is_map(value) and not is_struct(value) and map_size(value) <= @max_entries do
    Enum.reduce_while(value, {:ok, %{}, counts}, fn {key, item}, {:ok, acc, current} ->
      if valid_key?(key) do
        if DataPolicy.classify_key(key) == :secret_value do
          {:cont, {:ok, Map.put(acc, key, @redacted), current |> checked() |> redacted()}}
        else
          case sanitize(item, depth + 1, current) do
            {:ok, sanitized, next} -> {:cont, {:ok, Map.put(acc, key, sanitized), next}}
            {:error, error} -> {:halt, {:error, error}}
          end
        end
      else
        {:halt, {:error, Error.new(:invalid_input, :redaction_key)}}
      end
    end)
  end

  defp sanitize(_value, _depth, _counts),
    do: {:error, Error.new(:invalid_input, :redaction_shape)}

  defp sensitive_string?(value), do: Enum.any?(@secret_patterns, &Regex.match?(&1, value))
  defp valid_key?(key), do: is_atom(key) or (is_binary(key) and byte_size(key) <= 80)
  defp checked(counts), do: Map.update!(counts, :checked, &(&1 + 1))
  defp redacted(counts), do: Map.update!(counts, :redacted, &(&1 + 1))
end
