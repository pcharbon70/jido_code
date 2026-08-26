defmodule JidoCode.Knowledge.Ontology.DelegatedAgentOntologyTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.Validation.ShapeCatalog

  @jf "https://jido.run/ontology/factory#"
  @jfc "https://jido.run/ontology/concept/"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @owl_class "http://www.w3.org/2002/07/owl#Class"
  @owl_deprecated "http://www.w3.org/2002/07/owl#deprecated"

  test "release 1.4.0 contains delegated resources and adapter-boundary legacy vocabulary" do
    assert {:ok, dataset} = Release.dataset("1.4.0")
    quads = RDF.Dataset.quads(dataset)

    for class <- ~w[DelegatedAdapterRelease DelegatedAgentProfile DelegatedAgentReadiness] do
      assert Enum.any?(quads, fn {subject, predicate, object, _graph} ->
               to_string(subject) == @jf <> class and to_string(predicate) == @rdf_type and
                 to_string(object) == @owl_class
             end)

      assert ShapeCatalog.allowed_class?(:factory_policy, @jf <> class)
    end

    assert Enum.any?(quads, fn {subject, predicate, object, _graph} ->
             to_string(subject) == @jfc <> "DeveloperLocalCli" and
               to_string(predicate) == @owl_deprecated and to_string(object) == "true"
           end)
  end
end
