defmodule JidoCode.Product.ProtectedInput do
  @moduledoc "Reads bounded CLI request and credential bytes from protected channels."

  import Bitwise

  @request_limit 65_536
  @credential_limit 512

  @spec request_from_stdin() :: {:ok, binary()} | {:error, atom()}
  def request_from_stdin do
    case IO.read(:stdio, @request_limit + 1) do
      bytes when is_binary(bytes) -> bounded(bytes, @request_limit)
      _error -> {:error, :unavailable}
    end
  end

  @spec request_from_file(Path.t()) :: {:ok, binary()} | {:error, atom()}
  def request_from_file(path), do: protected_file(path, @request_limit)

  @spec credential_from_file(Path.t()) :: {:ok, binary()} | {:error, atom()}
  def credential_from_file(path) do
    with {:ok, bytes} <- protected_file(path, @credential_limit),
         credential <- String.trim(bytes),
         true <- byte_size(credential) in 1..@credential_limit do
      {:ok, credential}
    else
      _invalid -> {:error, :unauthorized}
    end
  end

  defp protected_file(path, maximum) when is_binary(path) and byte_size(path) in 1..4_096 do
    with {:ok, stat} <- File.lstat(path, time: :posix),
         true <- stat.type == :regular,
         true <- (stat.mode &&& 0o077) == 0,
         {:ok, bytes} <- read_bounded_file(path, maximum),
         {:ok, bytes} <- bounded(bytes, maximum) do
      {:ok, bytes}
    else
      {:error, :invalid_input} -> {:error, :invalid_input}
      _invalid -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  end

  defp protected_file(_path, _maximum), do: {:error, :unavailable}

  defp read_bounded_file(path, maximum) do
    File.open(path, [:read, :binary], fn io ->
      case IO.binread(io, maximum + 1) do
        :eof -> ""
        bytes -> bytes
      end
    end)
  end

  defp bounded(bytes, maximum) when byte_size(bytes) >= 1 and byte_size(bytes) <= maximum,
    do: {:ok, bytes}

  defp bounded(_bytes, _maximum), do: {:error, :invalid_input}
end
