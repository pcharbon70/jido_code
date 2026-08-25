defmodule JidoCode.Product.GraphManagedCodingAttemptProvider do
  @moduledoc "Builds an attempt view from one reviewed, actor-scoped graph projection callback."

  @behaviour JidoCode.Product.ManagedCodingAttemptProvider

  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.ManagedCodingAttempt

  @impl true
  def load(%AuthorityContext{} = authority, identity, reference) when is_map(identity) do
    loader = Application.get_env(:jido_code, :managed_coding_attempt_graph_loader)

    with true <- ManagedCodingAttempt.valid_presentation_ref?(reference),
         loader when is_function(loader, 3) <- loader,
         {:ok, graph} <- loader.(authority, identity.factory_scope_iri, reference),
         {:ok, attempt} <- ManagedCodingAttempt.new(graph),
         true <- attempt.presentation_ref == reference,
         true <- attempt.actor_iri == authority.actor_iri do
      {:ok, attempt}
    else
      _unavailable -> {:error, :unavailable}
    end
  rescue
    _error -> {:error, :unavailable}
  end

  def load(_authority, _identity, _reference), do: {:error, :unauthorized}
end
