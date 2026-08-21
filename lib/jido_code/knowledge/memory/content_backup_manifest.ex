defmodule JidoCode.Knowledge.Memory.ContentBackupManifest do
  @moduledoc "Backup manifest with an erasure-generation restore floor and exclusions."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"

  def revision, do: @revision

  def new(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:backup_iri]),
         true <-
           is_integer(attributes[:erasure_generation]) and attributes.erasure_generation >= 0,
         true <- resource_list?(attributes[:excluded_content_iris]),
         true <- resource_list?(attributes[:excluded_key_iris]),
         %DateTime{} = created_at <- attributes[:created_at],
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :content_backup_manifest,
             Enum.join(
               [attributes.backup_iri, Integer.to_string(attributes.erasure_generation)],
               "\n"
             )
           ) do
      manifest = %{
        iri: iri,
        revision: @revision,
        backup_iri: attributes.backup_iri,
        erasure_generation: attributes.erasure_generation,
        excluded_content_iris: Enum.sort(attributes.excluded_content_iris),
        excluded_key_iris: Enum.sort(attributes.excluded_key_iris),
        created_at: created_at
      }

      {:ok, Map.put(manifest, :manifest_digest, digest_term(manifest))}
    else
      _invalid -> {:error, Error.new(:invalid_input, :content_backup_manifest)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :content_backup_manifest)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :content_backup_manifest)}

  def restore_allowed?(manifest, restore) when is_map(manifest) and is_map(restore) do
    restore[:erasure_generation] >= manifest.erasure_generation and
      MapSet.disjoint?(
        MapSet.new(restore[:content_iris] || []),
        MapSet.new(manifest.excluded_content_iris)
      ) and
      MapSet.disjoint?(
        MapSet.new(restore[:key_iris] || []),
        MapSet.new(manifest.excluded_key_iris)
      )
  rescue
    _error -> false
  end

  def restore_allowed?(_manifest, _restore), do: false

  defp resource_list?(values) when is_list(values),
    do:
      length(values) == length(Enum.uniq(values)) and
        Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok))

  defp resource_list?(_values), do: false

  defp digest_term(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
