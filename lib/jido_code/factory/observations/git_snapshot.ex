defmodule JidoCode.Factory.Observations.GitSnapshot do
  @moduledoc "Exact, bounded Git identity returned from a disposable worktree."

  alias JidoCode.Knowledge.Error

  @enforce_keys [
    :commit_sha,
    :tree_sha,
    :parents,
    :ref,
    :object_format,
    :submodules?,
    :lfs?,
    :clean?,
    :observed_at,
    :limitations
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    format = attributes[:object_format]

    with true <- format in [:sha1, :sha256],
         true <- object_id?(attributes[:commit_sha], format),
         true <- object_id?(attributes[:tree_sha], format),
         true <- is_list(attributes[:parents]) and length(attributes[:parents]) <= 100,
         true <- Enum.all?(attributes[:parents], &object_id?(&1, format)),
         true <- valid_ref?(attributes[:ref]),
         true <- Enum.all?([:submodules?, :lfs?, :clean?], &is_boolean(attributes[&1])),
         %DateTime{} = observed_at <- attributes[:observed_at],
         true <- is_list(attributes[:limitations]) and length(attributes[:limitations]) <= 50 do
      {:ok,
       %__MODULE__{
         commit_sha: String.downcase(attributes[:commit_sha]),
         tree_sha: String.downcase(attributes[:tree_sha]),
         parents: Enum.map(attributes[:parents], &String.downcase/1),
         ref: attributes[:ref],
         object_format: format,
         submodules?: attributes[:submodules?],
         lfs?: attributes[:lfs?],
         clean?: attributes[:clean?],
         observed_at: DateTime.truncate(observed_at, :microsecond),
         limitations: Enum.map(attributes[:limitations], &to_string/1)
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :git_snapshot)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :git_snapshot)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :git_snapshot)}

  defp object_id?(value, :sha1), do: hex?(value, 40)
  defp object_id?(value, :sha256), do: hex?(value, 64)

  defp hex?(value, length) do
    is_binary(value) and byte_size(value) == length and Regex.match?(~r/^[a-fA-F0-9]+$/, value)
  end

  defp valid_ref?(value) do
    is_binary(value) and byte_size(value) in 1..256 and not String.starts_with?(value, "-") and
      not Regex.match?(~r/[\x00-\x20~^:?*\\\[]/, value) and
      not String.contains?(value, ["..", "@{", "//"])
  end
end
