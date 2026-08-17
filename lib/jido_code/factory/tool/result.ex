defmodule JidoCode.Factory.Tool.Result do
  @moduledoc "Bounded, redacted result returned by a tool adapter."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @statuses ~w[completed failed timed_out cancelled rejected]a
  @enforce_keys [
    :status,
    :exit_status,
    :stdout,
    :stderr,
    :external_output_iris,
    :usage,
    :artifact_iris,
    :redaction
  ]
  defstruct @enforce_keys ++ [external_effect_id: nil]

  @type t :: %__MODULE__{}

  @spec new(map(), pos_integer()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes, output_limit) when is_map(attributes) and is_integer(output_limit) do
    with status when status in @statuses <- attributes[:status],
         :ok <- exit_status(attributes[:exit_status]),
         stdout when is_binary(stdout) <- attributes[:stdout],
         stderr when is_binary(stderr) <- attributes[:stderr],
         true <- byte_size(stdout) + byte_size(stderr) <= output_limit,
         :ok <- resources(attributes[:external_output_iris]),
         usage when is_map(usage) <- attributes[:usage],
         true <- byte_size(:erlang.term_to_binary(usage, [:deterministic])) <= 4_096,
         :ok <- resources(attributes[:artifact_iris]),
         redaction when redaction in [:none, :applied, :fully_redacted] <- attributes[:redaction],
         :ok <- external_effect_id(attributes[:external_effect_id]),
         false <- secret?(stdout) or secret?(stderr) do
      values =
        attributes
        |> Map.take(@enforce_keys)
        |> Map.put(:external_effect_id, attributes[:external_effect_id])

      {:ok, struct!(__MODULE__, values)}
    else
      _invalid -> {:error, AdapterError.new(:corrupt, :tool_result)}
    end
  rescue
    _error -> {:error, AdapterError.new(:corrupt, :tool_result)}
  end

  def new(_attributes, _limit), do: {:error, AdapterError.new(:invalid_input, :tool_result)}

  defp exit_status(nil), do: :ok
  defp exit_status(value) when is_integer(value) and value in 0..255, do: :ok
  defp exit_status(_value), do: :error

  defp resources(values) when is_list(values) and length(values) <= 100 do
    if Enum.all?(values, &(Knowledge.validate_resource_identity(&1) == :ok)),
      do: :ok,
      else: :error
  end

  defp resources(_values), do: :error

  defp external_effect_id(nil), do: :ok

  defp external_effect_id(value) when is_binary(value) do
    if byte_size(value) in 1..256 and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value),
      do: :ok,
      else: :error
  end

  defp external_effect_id(_value), do: :error

  defp secret?(value) do
    Regex.match?(
      ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,})\b|(?:password|token|secret)\s*[=:]\s*\S+)/i,
      value
    )
  end
end
