defmodule JidoCode.Product.AgentCatalogGateway do
  @moduledoc "Authenticated, scope-bounded gateway for unified native and delegated offerings."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.AgentOffering
  alias JidoCode.Product.GraphAgentCatalogProvider
  alias JidoCode.Security.Redactor

  @allowed ~w[repository_ref snapshot_ref task_class language_class capability_class rollout_stage]
  @rollout ~w[evaluation shadow pilot production]
  @maximum_offerings 64

  @spec list(AuthorityContext.t(), map(), map(), keyword()) ::
          {:ok, [AgentOffering.t()]} | {:error, AdapterError.t()}
  def list(authority, identity, params, options \\ [])

  def list(%AuthorityContext{} = authority, identity, params, options)
      when is_map(identity) and is_map(params) and is_list(options) do
    provider = Keyword.get(options, :provider, GraphAgentCatalogProvider)
    clock = Keyword.get(options, :clock, &DateTime.utc_now/0)

    with true <- authority.actor_iri == identity.actor_iri,
         true <- Map.keys(params) |> Enum.all?(&(to_string(&1) in @allowed)),
         :ok <- Redactor.reject_sensitive(params),
         {:ok, scope} <- scope(identity, params, clock),
         {:ok, offerings} <- provider_list(provider, authority, identity, scope),
         true <- length(offerings) <= @maximum_offerings,
         true <- Enum.all?(offerings, &safe_offering?/1) do
      {:ok, Enum.sort_by(offerings, &{&1.display_name, &1.reference})}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      {:error, :unavailable} -> error(:unavailable)
      _invalid -> error(:invalid_input)
    end
  rescue
    _error -> error(:invalid_input)
  end

  def list(_authority, _identity, _params, _options), do: error(:invalid_input)

  defp scope(identity, params, clock) do
    with {:ok, repository_ref} <- required_ref(params, "repository_ref"),
         {:ok, snapshot_ref} <- required_ref(params, "snapshot_ref"),
         {:ok, task_class} <- identifier(params, "task_class"),
         {:ok, language_class} <- identifier(params, "language_class"),
         {:ok, capability_class} <- identifier(params, "capability_class"),
         {:ok, rollout_stage} <- rollout(params),
         %DateTime{} = at <- clock.() |> DateTime.truncate(:microsecond) do
      {:ok,
       %{
         actor_iri: identity.actor_iri,
         tenant_iri: identity.factory_scope_iri,
         repository_ref: repository_ref,
         snapshot_ref: snapshot_ref,
         task_class: task_class,
         language_class: language_class,
         capability_class: capability_class,
         rollout_stage: rollout_stage,
         at: at
       }}
    else
      _invalid -> :error
    end
  end

  defp provider_list(provider, authority, identity, scope) when is_atom(provider) do
    if Code.ensure_loaded?(provider) and function_exported?(provider, :list, 3),
      do: provider.list(authority, identity, scope),
      else: {:error, :unavailable}
  end

  defp provider_list(provider, authority, identity, scope) when is_function(provider, 3),
    do: provider.(authority, identity, scope)

  defp provider_list(_provider, _authority, _identity, _scope), do: {:error, :unavailable}

  defp safe_offering?(%AgentOffering{} = offering) do
    with map <- AgentOffering.safe_map(offering),
         :ok <- Redactor.reject_sensitive(inspect(map)),
         true <- is_binary(offering.reference),
         true <- byte_size(offering.reference) in 16..96,
         true <- Regex.match?(~r/^[A-Za-z0-9_-]+$/, offering.reference) do
      true
    else
      _unsafe -> false
    end
  end

  defp safe_offering?(_offering), do: false

  defp required_ref(params, key) do
    value = params[key] || params[String.to_existing_atom(key)]

    if is_binary(value) and byte_size(value) in 16..160 and
         Regex.match?(~r/^[A-Za-z0-9_-]+$/, value),
       do: {:ok, value},
       else: :error
  rescue
    ArgumentError -> :error
  end

  defp identifier(params, key) do
    value = params[key] || params[String.to_existing_atom(key)]

    if is_binary(value) and byte_size(value) in 1..64 and
         Regex.match?(~r/^[a-z][a-z0-9_]*$/, value),
       do: {:ok, value},
       else: :error
  rescue
    ArgumentError -> :error
  end

  defp rollout(params) do
    value = params["rollout_stage"] || params[:rollout_stage] || "evaluation"
    if value in @rollout, do: {:ok, value}, else: :error
  end

  defp error(kind), do: {:error, AdapterError.new(kind, :agent_catalog_gateway)}
end
