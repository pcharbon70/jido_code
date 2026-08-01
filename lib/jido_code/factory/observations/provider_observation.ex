defmodule JidoCode.Factory.Observations.ProviderObservation do
  @moduledoc """
  Bounded, normalized provider evidence.

  This value deliberately excludes raw response bodies, credentials, private
  URLs, local paths, graph placement, and semantic acceptance state.
  """

  alias JidoCode.Knowledge.Error

  @enforce_keys [
    :kind,
    :external_id,
    :source_time,
    :retrieved_at,
    :etag,
    :source_revision,
    :response_digest,
    :data,
    :completeness,
    :limitations,
    :warnings
  ]
  defstruct @enforce_keys

  @type kind :: :repository | :issue | :pull_request | :branch | :webhook | :ci | :capability
  @type t :: %__MODULE__{}

  @kinds ~w[repository issue pull_request branch webhook ci capability]a
  @completeness_states ~w[complete partial unknown]a
  @forbidden_keys ~w[
    authorization credential secret token password private_url clone_url ssh_url html_url
    body raw payload source_text local_path worktree_path graph_iri graph
  ]

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with kind when kind in @kinds <- attributes[:kind],
         true <- valid_text?(attributes[:external_id], 256),
         true <- optional_time?(attributes[:source_time]),
         %DateTime{} = retrieved_at <- attributes[:retrieved_at],
         true <- optional_text?(attributes[:etag], 512),
         true <- optional_text?(attributes[:source_revision], 256),
         true <- digest?(attributes[:response_digest]),
         :ok <- safe_value(attributes[:data], 0),
         {:ok, completeness} <- completeness(attributes[:completeness]),
         {:ok, limitations} <- text_list(attributes[:limitations], 50, 256),
         {:ok, warnings} <- text_list(attributes[:warnings], 50, 256) do
      {:ok,
       %__MODULE__{
         kind: kind,
         external_id: attributes[:external_id],
         source_time: truncate_time(attributes[:source_time]),
         retrieved_at: DateTime.truncate(retrieved_at, :microsecond),
         etag: attributes[:etag],
         source_revision: attributes[:source_revision],
         response_digest: attributes[:response_digest],
         data: attributes[:data],
         completeness: completeness,
         limitations: limitations,
         warnings: warnings
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  defp completeness(%{status: status} = value) when status in @completeness_states do
    covered = Map.get(value, :covered, [])
    missing = Map.get(value, :missing, [])

    with {:ok, covered} <- text_list(covered, 100, 128),
         {:ok, missing} <- text_list(missing, 100, 128) do
      {:ok, %{status: status, covered: covered, missing: missing}}
    end
  end

  defp completeness(_value), do: invalid()

  defp safe_value(value, _depth)
       when is_binary(value) or is_boolean(value) or is_number(value) or is_nil(value),
       do: :ok

  defp safe_value(value, depth) when is_list(value) and depth < 5 and length(value) <= 200 do
    reduce_values(value, depth)
  end

  defp safe_value(value, depth) when is_map(value) and depth < 5 and map_size(value) <= 100 do
    Enum.reduce_while(value, :ok, fn {key, item}, :ok ->
      normalized_key = key |> to_string() |> String.downcase()

      if normalized_key in @forbidden_keys or
           String.contains?(normalized_key, ["secret", "token"]) do
        {:halt, invalid()}
      else
        case safe_value(item, depth + 1) do
          :ok -> {:cont, :ok}
          {:error, %Error{} = error} -> {:halt, {:error, error}}
        end
      end
    end)
  end

  defp safe_value(_value, _depth), do: invalid()

  defp reduce_values(values, depth) do
    Enum.reduce_while(values, :ok, fn item, :ok ->
      case safe_value(item, depth + 1) do
        :ok -> {:cont, :ok}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp text_list(values, maximum_count, maximum_bytes)
       when is_list(values) and length(values) <= maximum_count do
    normalized = Enum.map(values, &normalize_text/1)

    if Enum.all?(normalized, &valid_text?(&1, maximum_bytes)),
      do: {:ok, Enum.uniq(normalized)},
      else: invalid()
  end

  defp text_list(_values, _maximum_count, _maximum_bytes), do: invalid()

  defp normalize_text(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_text(value), do: value

  defp valid_text?(value, maximum) do
    is_binary(value) and byte_size(value) in 1..maximum and
      not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
  end

  defp optional_text?(nil, _maximum), do: true
  defp optional_text?(value, maximum), do: valid_text?(value, maximum)
  defp optional_time?(nil), do: true
  defp optional_time?(%DateTime{}), do: true
  defp optional_time?(_value), do: false
  defp truncate_time(nil), do: nil
  defp truncate_time(time), do: DateTime.truncate(time, :microsecond)
  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)
  defp invalid, do: {:error, Error.new(:invalid_input, :provider_observation)}
end
