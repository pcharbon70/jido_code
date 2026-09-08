defmodule JidoCode.LocalInstall do
  @moduledoc "One-time local ceremony binding the first named human to pristine graph authority."

  def bootstrap(attributes, credential, operator_token) do
    attributes =
      Map.merge(attributes, %{
        roles: [:factory_administrator, :observer],
        route_groups: [:administration, :developer]
      })

    with true <- JidoCode.LocalDeployment.active?(),
         {:ok, account} <-
           JidoCode.Identity.bootstrap(attributes, credential, local_ceremony: true) do
      complete_graph_bootstrap(account.subject_ref, operator_token)
    else
      false -> {:error, :local_profile_required}
      error -> error
    end
  end

  @doc "Resume a partial local ceremony using its existing named human; never reinitialize identity."
  def complete_graph_bootstrap(subject_ref, operator_token) do
    with true <- JidoCode.LocalDeployment.active?(),
         {:ok, %{status: :active}} <- JidoCode.Identity.account(subject_ref) do
      surface = Application.fetch_env!(:jido_code, :product_surface)
      human = "https://jido.run/id/human/#{subject_ref}"

      JidoCode.Install.bootstrap(operator_token,
        identity: %{
          factory_iri: Keyword.fetch!(surface, :factory_iri),
          factory_scope_iri: Keyword.fetch!(surface, :factory_scope_iri),
          principal_iri: human,
          actor_iri: human
        }
      )
    else
      _ -> {:error, :local_bootstrap_unavailable}
    end
  end
end
