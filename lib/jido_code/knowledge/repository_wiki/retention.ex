defmodule JidoCode.Knowledge.RepositoryWiki.Retention do
  @moduledoc "Closed retention and backup contract for repository wiki resources."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract

  @classes %{
    current: %{minimum: :while_current, backup: true, readable: true},
    superseded: %{minimum: :repository_history, backup: true, readable: true},
    preview: %{minimum: :bounded_expiry, backup: false, readable: :authorized_session},
    incomplete: %{minimum: :recovery_window, backup: true, readable: false},
    invalid: %{minimum: :audit_window, backup: true, readable: false},
    source_snapshot: %{minimum: :longest_citing_edition, backup: true, readable: false},
    render_artifact: %{minimum: :disposable, backup: false, readable: false},
    accounting: %{minimum: :finance_and_edition, backup: true, readable: :privileged},
    audit: %{minimum: :audit_policy, backup: true, readable: :privileged}
  }

  @restore_order [:repository_control, :repository_wiki, :render_cache, :search_index]

  def classes, do: @classes
  def restore_order, do: @restore_order

  @spec backup_manifest(map()) :: {:ok, map()} | {:error, Error.t()}
  def backup_manifest(attributes) when is_map(attributes) do
    required = [
      :repository_iri,
      :tenant_iri,
      :enrollment_iri,
      :edition_iri,
      :graph_iri,
      :source_snapshot_iri,
      :source_fence,
      :compiler_profile,
      :compiler_digest,
      :lineage,
      :current_pointer,
      :retention_class,
      :audit_iris
    ]

    with true <- Enum.all?(required, &Map.has_key?(attributes, &1)),
         true <- attributes[:retention_class] in Map.keys(@classes),
         true <- is_list(attributes[:lineage]),
         true <- is_list(attributes[:audit_iris]) and attributes.audit_iris != [],
         true <- Contract.digest?(attributes[:compiler_digest]) do
      payload = Map.take(attributes, required)

      {:ok,
       %{
         version: "repository-wiki-backup/1.0.0",
         restore_order: @restore_order,
         payload: payload,
         digest: Contract.digest(payload)
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :repository_wiki_backup_manifest)}
    end
  end

  def backup_manifest(_attributes),
    do: {:error, Error.new(:invalid_input, :repository_wiki_backup_manifest)}
end
