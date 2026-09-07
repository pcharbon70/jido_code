defmodule JidoCode.Identity.Authority.LocalGraph do
  @moduledoc "Read-only named-human grants from the current local graph, never from role names."
  @behaviour JidoCode.Identity.AuthorityAdapter
  alias JidoCode.Identity.{AuthorityRequest, Resource}
  alias JidoCode.Knowledge.{AuthorityContext, Error, GraphRegistry, QueryRunner}

  @impl true
  def resolve(identity, _memberships, _delegations, resource, request) do
    with {:ok, _} <- AuthorityRequest.validate(request),
         true <- request.action in [:page, :query, :field, :stream],
         true <- request.area == :developer,
         {:ok, {name, graph, scope}} <- binding(identity, resource, request.operation),
         {:ok, authority} <-
           AuthorityContext.new(%{
             principal_iri: identity.principal_iri,
             actor_iri: identity.actor_iri
           }),
         {:ok, grant} <-
           QueryRunner.authorize(
             name,
             "2.11.0",
             %{graph: graph, resource: resource.iri},
             authority,
             scope
           ) do
      {:ok, grant}
    else
      {:error, %Error{kind: :unauthorized}} -> {:error, :concealed_not_found}
      {:error, %Error{}} -> {:error, :unavailable}
      _ -> {:error, :denied}
    end
  rescue
    _ -> {:error, :unavailable}
  end

  defp binding(identity, %Resource{kind: :factory, iri: iri}, operation)
       when operation in [:factory_shell, :project_page] do
    with true <- iri == identity.factory_iri,
         {:ok, graph} <- GraphRegistry.graph_iri(:factory_catalog, %{}) do
      {:ok, {:factory_repository_cohort, graph, identity.factory_scope_iri}}
    end
  end

  defp binding(identity, %Resource{kind: :project}, :project_page) do
    with {:ok, graph} <- GraphRegistry.graph_iri(:factory_catalog, %{}),
         do: {:ok, {:repository_description, graph, identity.factory_scope_iri}}
  end

  defp binding(_identity, %Resource{kind: :attempt} = resource, :attempt_page) do
    with {:ok, graph} <- GraphRegistry.graph_iri(:run_attempt, %{attempt: resource.iri}),
         do: {:ok, {:attempt_status, graph, resource.graph_scope_iri}}
  end

  defp binding(_, _, _), do: {:error, :unsupported_read_scope}
end
