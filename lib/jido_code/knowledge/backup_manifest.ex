defmodule JidoCode.Knowledge.BackupManifest do
  @moduledoc """
  Validated metadata for a store backup or standards-based RDF export.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Metadata

  @format_version 1
  @artifact_kinds [:checkpoint, :nquads, :trig]

  @enforce_keys [
    :artifact_id,
    :artifact_kind,
    :created_at,
    :dataset_revision,
    :system_graph_revision,
    :store_schema_version,
    :backend_schema_version,
    :lineage,
    :graph_count,
    :quad_count,
    :payload_path,
    :payload_sha256,
    :payload_bytes,
    :file_count
  ]
  defstruct [
    :artifact_id,
    :artifact_kind,
    :created_at,
    :dataset_revision,
    :system_graph_revision,
    :store_schema_version,
    :backend_schema_version,
    :lineage,
    :graph_count,
    :quad_count,
    :payload_path,
    :payload_sha256,
    :payload_bytes,
    :file_count,
    format_version: @format_version,
    consistency: "exclusive_store_owner"
  ]

  @type t :: %__MODULE__{
          artifact_id: String.t(),
          artifact_kind: :checkpoint | :nquads | :trig,
          created_at: String.t(),
          dataset_revision: non_neg_integer(),
          system_graph_revision: non_neg_integer(),
          store_schema_version: pos_integer(),
          backend_schema_version: pos_integer(),
          lineage: String.t(),
          graph_count: non_neg_integer(),
          quad_count: non_neg_integer(),
          payload_path: String.t(),
          payload_sha256: String.t(),
          payload_bytes: non_neg_integer(),
          file_count: pos_integer(),
          format_version: pos_integer(),
          consistency: String.t()
        }

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    manifest = struct(__MODULE__, attributes)

    if valid?(manifest) do
      {:ok, manifest}
    else
      {:error, Error.new(:invalid_input, :validate_backup_manifest)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :validate_backup_manifest)}
  end

  @spec decode(String.t()) :: {:ok, t()} | {:error, Error.t()}
  def decode(json) when is_binary(json) do
    with {:ok, values} <- Jason.decode(json),
         {:ok, kind} <- decode_kind(values["artifact_kind"]),
         {:ok, manifest} <-
           new(%{
             artifact_id: values["artifact_id"],
             artifact_kind: kind,
             created_at: values["created_at"],
             dataset_revision: values["dataset_revision"],
             system_graph_revision: values["system_graph_revision"],
             store_schema_version: values["store_schema_version"],
             backend_schema_version: values["backend_schema_version"],
             lineage: values["lineage"],
             graph_count: values["graph_count"],
             quad_count: values["quad_count"],
             payload_path: values["payload_path"],
             payload_sha256: values["payload_sha256"],
             payload_bytes: values["payload_bytes"],
             file_count: values["file_count"],
             format_version: values["format_version"],
             consistency: values["consistency"]
           }) do
      {:ok, manifest}
    else
      _error -> {:error, Error.new(:corrupt, :read_backup_manifest)}
    end
  end

  @spec encode!(t()) :: String.t()
  def encode!(%__MODULE__{} = manifest) do
    manifest
    |> Map.from_struct()
    |> Map.update!(:artifact_kind, &Atom.to_string/1)
    |> Jason.encode!(pretty: true)
  end

  @spec compatible?(t(), pos_integer()) :: boolean()
  def compatible?(%__MODULE__{} = manifest, store_schema_version) do
    manifest.artifact_kind == :checkpoint and
      manifest.store_schema_version == store_schema_version and
      manifest.backend_schema_version == Metadata.backend_schema_version()
  end

  defp valid?(manifest) do
    manifest.format_version == @format_version and
      manifest.artifact_kind in @artifact_kinds and
      valid_artifact_id?(manifest.artifact_id) and
      valid_timestamp?(manifest.created_at) and
      valid_nonnegative?(manifest.dataset_revision) and
      valid_nonnegative?(manifest.system_graph_revision) and
      is_integer(manifest.store_schema_version) and manifest.store_schema_version > 0 and
      is_integer(manifest.backend_schema_version) and manifest.backend_schema_version > 0 and
      is_binary(manifest.lineage) and RDF.IRI.valid?(manifest.lineage) and
      valid_nonnegative?(manifest.graph_count) and valid_nonnegative?(manifest.quad_count) and
      valid_payload_path?(manifest.payload_path, manifest.artifact_kind) and
      valid_digest?(manifest.payload_sha256) and valid_nonnegative?(manifest.payload_bytes) and
      is_integer(manifest.file_count) and manifest.file_count > 0 and
      manifest.consistency == "exclusive_store_owner"
  end

  defp valid_artifact_id?(value) when is_binary(value) do
    Regex.match?(~r/^artifact-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{16}$/, value)
  end

  defp valid_artifact_id?(_value), do: false

  defp valid_timestamp?(value) when is_binary(value) do
    match?({:ok, _datetime, 0}, DateTime.from_iso8601(value))
  end

  defp valid_timestamp?(_value), do: false

  defp valid_payload_path?("checkpoint", :checkpoint), do: true
  defp valid_payload_path?("dataset.nq", :nquads), do: true
  defp valid_payload_path?("dataset.trig", :trig), do: true
  defp valid_payload_path?(_path, _kind), do: false

  defp valid_digest?(value) when is_binary(value) do
    byte_size(value) == 64 and Regex.match?(~r/^[0-9a-f]{64}$/, value)
  end

  defp valid_digest?(_value), do: false
  defp valid_nonnegative?(value), do: is_integer(value) and value >= 0

  defp decode_kind("checkpoint"), do: {:ok, :checkpoint}
  defp decode_kind("nquads"), do: {:ok, :nquads}
  defp decode_kind("trig"), do: {:ok, :trig}
  defp decode_kind(_value), do: :error
end
