defmodule JidoCode.Knowledge.Memory.DerivativeCleanup do
  @moduledoc "Invalidates or rebuilds every projection whose lineage includes erased content."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"

  def revision, do: @revision

  def plan(erased_content_iris, projections)
      when is_list(erased_content_iris) and is_list(projections) do
    erased = MapSet.new(erased_content_iris)

    with true <- erased != MapSet.new(),
         true <- Enum.all?(erased, &(ResourceIdentity.validate(&1) == :ok)),
         true <- Enum.all?(projections, &projection?/1) do
      actions =
        projections
        |> Enum.filter(fn projection ->
          not MapSet.disjoint?(erased, MapSet.new(projection.lineage_content_iris))
        end)
        |> Enum.map(fn projection ->
          %{
            projection_iri: projection.iri,
            action: if(projection.rebuildable?, do: :rebuild, else: :invalidate),
            erased_lineage:
              Enum.filter(projection.lineage_content_iris, &MapSet.member?(erased, &1))
          }
        end)
        |> Enum.sort_by(& &1.projection_iri)

      {:ok, %{revision: @revision, actions: actions, complete?: true}}
    else
      _invalid -> {:error, Error.new(:invalid_input, :derivative_cleanup)}
    end
  end

  def plan(_erased, _projections), do: {:error, Error.new(:invalid_input, :derivative_cleanup)}

  defp projection?(projection) when is_map(projection) do
    ResourceIdentity.validate(projection[:iri]) == :ok and is_boolean(projection[:rebuildable?]) and
      is_list(projection[:lineage_content_iris]) and
      Enum.all?(projection.lineage_content_iris, &(ResourceIdentity.validate(&1) == :ok))
  end

  defp projection?(_projection), do: false
end
