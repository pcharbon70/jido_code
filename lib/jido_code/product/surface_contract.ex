defmodule JidoCode.Product.SurfaceContract do
  @moduledoc """
  Closed route and ownership contract for the repository factory workbench.

  The browser may select one of these presentation areas, but it cannot select
  graph names, query names, modules, capabilities, or command types.
  """

  alias JidoCode.Knowledge.ResourceIdentity

  @surfaces [
    %{
      id: "factory",
      label: "Factory",
      icon: "hero-squares-2x2",
      projection: :factory_posture,
      description: "Fleet posture, graph health, and repository admission"
    },
    %{
      id: "repositories",
      label: "Repositories",
      icon: "hero-code-bracket-square",
      projection: :repository_catalog,
      description: "Enrollment, observation, source freshness, and recovery"
    },
    %{
      id: "work",
      label: "Work",
      icon: "hero-queue-list",
      projection: :work_queue,
      description: "Goals, plans, policy obligations, eligibility, and blockers"
    },
    %{
      id: "execution",
      label: "Execution",
      icon: "hero-command-line",
      projection: :execution_activity,
      description: "Leases, attempts, interactions, artifacts, and recovery"
    },
    %{
      id: "outcomes",
      label: "Outcomes",
      icon: "hero-check-badge",
      projection: :accepted_outcomes,
      description: "Evidence, decisions, follow-up, and satisfaction"
    },
    %{
      id: "knowledge",
      label: "Knowledge",
      icon: "hero-light-bulb",
      projection: :accepted_knowledge,
      description: "Adopted assertions, provenance, and contradiction"
    },
    %{
      id: "wiki",
      label: "Wiki",
      icon: "hero-book-open",
      projection: :repository_wiki,
      description: "Current repository guides, architecture, dependencies, and provenance"
    }
  ]

  @surface_ids Enum.map(@surfaces, & &1.id)
  @max_ref_bytes 1_024

  @spec all() :: [map()]
  def all, do: @surfaces

  @spec default() :: map()
  def default, do: hd(@surfaces)

  @spec fetch(String.t() | nil) :: map()
  def fetch(id) when id in @surface_ids, do: Enum.find(@surfaces, &(&1.id == id))
  def fetch(_id), do: default()

  @spec visible(String.t() | nil, boolean()) :: [map()]
  def visible(repository_iri, wiki_visible?) when is_binary(repository_iri) and wiki_visible?,
    do: @surfaces

  def visible(_repository_iri, _wiki_visible?),
    do: Enum.reject(@surfaces, &(&1.id == "wiki"))

  @spec encode_resource(String.t()) :: {:ok, String.t()} | :error
  def encode_resource(iri) when is_binary(iri) do
    with true <- byte_size(iri) <= @max_ref_bytes,
         :ok <- ResourceIdentity.validate(iri) do
      {:ok, Base.url_encode64(iri, padding: false)}
    else
      _invalid -> :error
    end
  end

  def encode_resource(_iri), do: :error

  @spec decode_resource(String.t() | nil) :: {:ok, String.t()} | :error
  def decode_resource(ref) when is_binary(ref) and byte_size(ref) <= 1_400 do
    with {:ok, iri} <- Base.url_decode64(ref, padding: false),
         true <- byte_size(iri) <= @max_ref_bytes,
         :ok <- ResourceIdentity.validate(iri) do
      {:ok, iri}
    else
      _invalid -> :error
    end
  end

  def decode_resource(_ref), do: :error
end
