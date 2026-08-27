defmodule JidoCode.Integrations.DelegatedArtifactRepository do
  @moduledoc "Provider-style immutable artifact storage; graph pins remain the sole authority."

  @behaviour JidoCode.Factory.Ports.DelegatedArtifactStore

  @architecture_file_role :build_artifact

  alias JidoCode.Factory.AdapterError

  @max_bytes 1_048_576
  @digest ~r/^[a-f0-9]{64}$/

  @spec architecture_file_role() :: :build_artifact
  def architecture_file_role, do: @architecture_file_role

  @spec open(Path.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def open(root) when is_binary(root) do
    with true <- Path.type(root) == :absolute and Path.expand(root) == root,
         :ok <- File.mkdir_p(root),
         :ok <- File.chmod(root, 0o700),
         {:ok, %File.Stat{type: :directory}} <- File.lstat(root) do
      {:ok, %{root: root}}
    else
      _invalid -> invalid(:delegated_artifact_repository)
    end
  rescue
    _error -> invalid(:delegated_artifact_repository)
  end

  def open(_root), do: invalid(:delegated_artifact_repository)

  @impl true
  def put(%{root: root}, request) when is_map(request) do
    with content when is_binary(content) and byte_size(content) <= @max_bytes <- request[:content],
         media_type when media_type in ["text/x-diff", "application/vnd.jido.checkpoint"] <-
           request[:media_type],
         digest <- digest(content),
         expected when expected in [nil, digest] <- request[:expected_digest],
         path <- Path.join(root, digest),
         :ok <- create_once(path, content),
         {:ok, verified} <- read_verified(path, digest, @max_bytes) do
      {:ok,
       %{
         artifact_iri: "https://jido.run/id/delegated-artifact/#{digest}",
         digest: digest,
         byte_count: byte_size(verified),
         media_type: media_type,
         immutable: true
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:delegated_artifact_put)
    end
  rescue
    _error -> unavailable(:delegated_artifact_put)
  end

  def put(_repository, _request), do: invalid(:delegated_artifact_put)

  @impl true
  def fetch(%{root: root}, request) when is_map(request) do
    with digest when is_binary(digest) <- request[:digest],
         true <- Regex.match?(@digest, digest),
         maximum when is_integer(maximum) and maximum in 1..@max_bytes <-
           request[:maximum_bytes],
         expected_iri <- "https://jido.run/id/delegated-artifact/#{digest}",
         ^expected_iri <- request[:artifact_iri],
         {:ok, content} <- read_verified(Path.join(root, digest), digest, maximum) do
      {:ok,
       %{
         artifact_iri: expected_iri,
         digest: digest,
         byte_count: byte_size(content),
         content: content
       }}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:delegated_artifact_fetch)
    end
  rescue
    _error -> unavailable(:delegated_artifact_fetch)
  end

  def fetch(_repository, _request), do: invalid(:delegated_artifact_fetch)

  defp create_once(path, content) do
    case File.write(path, content, [:binary, :exclusive, :sync]) do
      :ok ->
        File.chmod(path, 0o400)

      {:error, :eexist} ->
        case read_verified(path, digest(content), @max_bytes) do
          {:ok, ^content} -> :ok
          _mismatch -> conflict(:delegated_artifact_immutable)
        end

      _error ->
        unavailable(:delegated_artifact_put)
    end
  end

  defp read_verified(path, expected_digest, maximum) do
    with {:ok, %File.Stat{type: :regular, size: size}} <- File.lstat(path),
         true <- size <= maximum,
         {:ok, content} <- File.read(path),
         ^expected_digest <- digest(content) do
      {:ok, content}
    else
      _invalid -> conflict(:delegated_artifact_integrity)
    end
  end

  defp digest(content),
    do: :sha256 |> :crypto.hash(content) |> Base.encode16(case: :lower)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
end
