defmodule JidoCode.Knowledge.RepositoryWiki.Retention do
  @moduledoc "Closed retention and backup contract for repository wiki resources."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Contract

  @classes %{
    current: %{minimum: :while_current, backup: true, readable: true},
    superseded: %{minimum: :repository_history, backup: true, readable: true},
    preview: %{minimum: :bounded_expiry, backup: false, readable: :authorized_session},
    expired_preview: %{minimum: :audit_tombstone, backup: false, readable: false},
    rejected: %{minimum: :review_history, backup: true, readable: false},
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

  @spec plan([map()], DateTime.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def plan(resources, %DateTime{} = evaluated_at, policy)
      when is_list(resources) and is_map(policy) and length(resources) <= 10_000 do
    with true <- valid_policy?(policy),
         true <- Enum.all?(resources, &valid_resource?/1) do
      actions =
        resources
        |> Enum.sort_by(&{&1.repository_iri, &1.class, &1.iri})
        |> Enum.map(&disposition(&1, evaluated_at, policy))

      {:ok,
       %{
         evaluated_at: evaluated_at,
         actions: actions,
         deletion_count: Enum.count(actions, &(&1.action == :delete_disposable)),
         compaction_count: Enum.count(actions, &(&1.action == :compact_keep_tombstone)),
         immutable_evidence_preserved?: Enum.all?(actions, & &1.immutable_evidence_preserved?),
         current_restoration_authority?: false
       }}
    else
      _invalid -> {:error, Error.new(:invalid_input, :repository_wiki_retention_plan)}
    end
  end

  def plan(_resources, _evaluated_at, _policy),
    do: {:error, Error.new(:invalid_input, :repository_wiki_retention_plan)}

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

  @spec restorable_as_current?(map(), map()) :: false
  def restorable_as_current?(_retained_history, _context), do: false

  defp disposition(resource, evaluated_at, policy) do
    expired? =
      match?(%DateTime{}, resource[:expires_at]) and
        DateTime.compare(evaluated_at, resource.expires_at) != :lt

    protected? =
      resource[:selected?] == true or resource[:cited?] == true or
        resource[:required_release?] == true or resource[:immutable_evidence?] == true

    action =
      cond do
        resource.class in [:current, :accounting, :audit] ->
          :retain

        protected? ->
          :retain

        resource.class == :superseded and policy.retain_superseded? ->
          :retain

        resource.class == :source_snapshot and resource[:cited?] == true ->
          :retain

        resource.class in [:preview, :expired_preview, :render_artifact] and expired? ->
          :delete_disposable

        resource.class in [:rejected, :invalid, :incomplete] and expired? ->
          :compact_keep_tombstone

        true ->
          :retain_until_deadline
      end

    %{
      iri: resource.iri,
      repository_iri: resource.repository_iri,
      class: resource.class,
      action: action,
      cache_namespace: resource[:cache_namespace],
      immutable_evidence_preserved?:
        resource[:immutable_evidence?] != true or action != :delete_disposable,
      retained_lineage?: action != :delete_disposable or resource.class == :render_artifact
    }
  end

  defp valid_policy?(policy) do
    is_boolean(policy[:retain_superseded?]) and
      policy[:classes] == @classes |> Map.keys() |> Enum.sort()
  end

  defp valid_resource?(resource) when is_map(resource) do
    Map.has_key?(resource, :iri) and is_binary(resource[:iri]) and
      Map.has_key?(resource, :repository_iri) and is_binary(resource[:repository_iri]) and
      resource[:class] in Map.keys(@classes) and
      (is_nil(resource[:expires_at]) or match?(%DateTime{}, resource[:expires_at]))
  end

  defp valid_resource?(_resource), do: false
end
