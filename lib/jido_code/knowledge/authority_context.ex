defmodule JidoCode.Knowledge.AuthorityContext do
  @moduledoc """
  Bounded transient projection supplied by the authentication boundary.

  This value identifies the authenticated principal and accountable graph
  actor. It contains no session, credential, token, or persisted authorization
  decision.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @derive {Inspect, only: [:principal_iri, :actor_iri, :delegated_agent_iri, :delegation_iri]}
  @enforce_keys [:principal_iri, :actor_iri, :delegated_agent_iri, :delegation_iri]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- ResourceIdentity.validate(attributes[:principal_iri]),
         :ok <- ResourceIdentity.validate(attributes[:actor_iri]),
         :ok <- optional_iri(attributes[:delegated_agent_iri]),
         :ok <- optional_iri(attributes[:delegation_iri]),
         :ok <- pair(attributes[:delegated_agent_iri], attributes[:delegation_iri]) do
      {:ok,
       %__MODULE__{
         principal_iri: attributes[:principal_iri],
         actor_iri: attributes[:actor_iri],
         delegated_agent_iri: attributes[:delegated_agent_iri],
         delegation_iri: attributes[:delegation_iri]
       }}
    end
  end

  def new(_attributes), do: invalid()

  defp optional_iri(nil), do: :ok
  defp optional_iri(value), do: ResourceIdentity.validate(value)
  defp pair(nil, nil), do: :ok
  defp pair(agent, delegation) when is_binary(agent) and is_binary(delegation), do: :ok
  defp pair(_agent, _delegation), do: invalid()
  defp invalid, do: {:error, Error.new(:invalid_input, :authority_context)}
end
