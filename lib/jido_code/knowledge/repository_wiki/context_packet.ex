defmodule JidoCode.Knowledge.RepositoryWiki.ContextPacket do
  @moduledoc """
  Immutable, source-fenced repository-wiki evidence for one coding attempt.

  Packet content is explicitly advisory and non-instructional. Its identity
  includes actor, tenant, repository, task, session, attempt, source, edition,
  compiler, enrollment, visibility, graph, and context-profile pins.
  """

  alias JidoCode.Knowledge.RepositoryWiki.Contract

  @revision "1.0.0"
  @enforce_keys [
    :revision,
    :digest,
    :profile_key,
    :profile_digest,
    :actor_iri,
    :tenant_iri,
    :repository_iri,
    :task_iri,
    :session_iri,
    :attempt_iri,
    :source_snapshot_iri,
    :source_revision,
    :enrollment_revision,
    :edition_iri,
    :edition_root,
    :compiler_profile,
    :compiler_digest,
    :dataset_revision,
    :wiki_graph_iri,
    :wiki_graph_revision,
    :fragments,
    :omissions,
    :usage,
    :evaluated_at,
    :non_authoritative?,
    :preview_context?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec build(map()) :: t()
  def build(attributes) when is_map(attributes) do
    material =
      attributes
      |> Map.put(:revision, @revision)
      |> Map.put(:non_authoritative?, true)
      |> Map.put(:preview_context?, false)
      |> Map.drop([:digest])

    struct!(__MODULE__, Map.put(material, :digest, Contract.digest(material)))
  end

  @spec valid?(term()) :: boolean()
  def valid?(%__MODULE__{} = packet) do
    material = packet |> Map.from_struct() |> Map.drop([:digest])

    packet.revision == @revision and packet.non_authoritative? == true and
      packet.preview_context? == false and Contract.digest(material) == packet.digest
  end

  def valid?(_packet), do: false
end
