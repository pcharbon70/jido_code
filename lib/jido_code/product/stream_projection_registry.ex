defmodule JidoCode.Product.StreamProjectionRegistry do
  @moduledoc "Closed stream refresh bindings, selected only after exact route authorization."
  alias JidoCode.Identity.{AuthorizationResult, Store}
  alias JidoCode.Knowledge.{AuthorityContext, ResourceIdentity}
  alias JidoCode.Product

  @cohort [
    :factory_catalog,
    :repository_control,
    :observation_batch,
    :run_attempt,
    :run_event_segment,
    :evidence
  ]
  @registry %{
    factory: @cohort,
    fleet: @cohort,
    projects: @cohort,
    project: @cohort,
    project_attempts: [
      :factory_catalog,
      :repository_control,
      :run_attempt,
      :run_event_segment,
      :evidence
    ],
    project_wiki: [:factory_catalog, :repository_control, :repository_wiki, :run_attempt],
    project_dependencies: [:factory_catalog, :repository_control, :source_revision],
    attempt: [:factory_catalog, :repository_control, :run_attempt, :run_event_segment, :evidence],
    account: [],
    sessions: []
  }

  def entries, do: @registry
  def root, do: "#product-owned-content"

  def build(%{key: key, authorization: %{decision: :allowed}}) when key in [:account, :sessions],
    do: {:ok, %{projection: key, scopes: [], families: [], root: root(), refresh: :identity_only}}

  def build(
        %{
          key: key,
          authorization: %AuthorizationResult{
            decision: :allowed,
            authority_context: %AuthorityContext{},
            product_identity: identity,
            current_scope: scope
          }
        } = page
      ) do
    with {:ok, families} <- Map.fetch(@registry, key),
         true <- families != [],
         :ok <- ResourceIdentity.validate(identity.factory_scope_iri),
         {:ok, scopes} <- scopes(page, scope, identity.factory_scope_iri) do
      {:ok,
       %{
         projection: key,
         scopes: Enum.uniq(scopes),
         families: families,
         root: root(),
         refresh: &Product.read_projection/2
       }}
    else
      _ -> {:error, :unregistered_subscription}
    end
  end

  def build(_), do: {:error, :unregistered_subscription}

  defp scopes(%{key: key}, %{resource_kind: :factory}, factory)
       when key in [:factory, :fleet, :projects], do: {:ok, [factory]}

  defp scopes(%{route_params: %{resource_ref: ref}}, %{resource_ref: ref}, factory) do
    with {:ok, resource} <- Store.resolve_resource(ref) do
      # Bootstrap resources may have no semantic subscription scope yet. Do not
      # fabricate one from a route/ref: factory hints plus reconciliation remain
      # sufficient, and the graph query continues to fail closed if unconfigured.
      if ResourceIdentity.validate(resource.graph_scope_iri) == :ok,
        do: {:ok, [factory, resource.graph_scope_iri]},
        else: {:ok, [factory]}
    end
  end

  defp scopes(_, _, _), do: {:error, :unregistered_subscription}
end
