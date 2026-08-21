defmodule JidoCode.Knowledge.Memory.ContentHygiene do
  @moduledoc "Pre-encryption secret, entropy, provider-private, and hidden-reasoning classifiers."

  alias JidoCode.Knowledge.Error

  @revision "1.0.0"
  @secret_pattern ~r/(?:-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_|sk-)[A-Za-z0-9_-]{16,}|(?:password|token|secret)\s*[=:]\s*\S+)/i
  @candidate_pattern ~r/[A-Za-z0-9+\/_=-]{32,}/

  def revision, do: @revision

  def inspect(plaintext, attributes) when is_binary(plaintext) and is_map(attributes) do
    canaries = attributes[:secret_canaries] || []
    provider_markers = attributes[:provider_private_markers] || []

    cond do
      plaintext == "" ->
        deny(:empty_content)

      attributes[:classification] == :secret_value ->
        deny(:secret_classification)

      attributes[:provider_private_state?] == true ->
        deny(:provider_private_state)

      attributes[:hidden_reasoning?] == true ->
        deny(:hidden_reasoning)

      not safe_markers?(canaries) ->
        deny(:secret_classifier_configuration)

      not safe_markers?(provider_markers) ->
        deny(:provider_classifier_configuration)

      Enum.any?(canaries, &String.contains?(plaintext, &1)) ->
        deny(:secret_canary)

      Enum.any?(provider_markers, &String.contains?(plaintext, &1)) ->
        deny(:provider_private_state)

      Regex.match?(@secret_pattern, plaintext) ->
        deny(:secret_pattern)

      high_entropy_secret?(plaintext) ->
        deny(:high_entropy_secret)

      true ->
        :ok
    end
  end

  def inspect(_plaintext, _attributes), do: deny(:content_hygiene)

  defp high_entropy_secret?(plaintext) do
    @candidate_pattern
    |> Regex.scan(plaintext)
    |> List.flatten()
    |> Enum.any?(&(entropy(&1) >= 4.5))
  end

  defp entropy(value) do
    size = byte_size(value)

    value
    |> :binary.bin_to_list()
    |> Enum.frequencies()
    |> Enum.reduce(0.0, fn {_byte, count}, total ->
      probability = count / size
      total - probability * :math.log2(probability)
    end)
  end

  defp safe_markers?(values) when is_list(values),
    do: Enum.all?(values, &(is_binary(&1) and byte_size(&1) in 8..256))

  defp safe_markers?(_values), do: false
  defp deny(operation), do: {:error, Error.new(:unauthorized, operation)}
end
