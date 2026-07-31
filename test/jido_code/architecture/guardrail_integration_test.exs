defmodule JidoCode.Architecture.GuardrailIntegrationTest do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.Checker
  alias JidoCode.Architecture.Violation

  @fixture_root "test/fixtures/architecture"

  test "every tracked prohibited fixture is rejected with an actionable rule" do
    sources = fixture_sources("prohibited")

    assert {:error, violations} = Checker.check_sources(sources)

    rejected_files = MapSet.new(violations, & &1.file)
    fixture_files = MapSet.new(sources, &elem(&1, 0))
    assert rejected_files == fixture_files

    rules = MapSet.new(violations, & &1.rule)

    assert MapSet.subset?(
             MapSet.new([
               :parallel_persistence,
               :store_ownership,
               :write_coordinator,
               :raw_store_access,
               :raw_rocksdb,
               :file_persistence,
               :presentation_raw_sparql,
               :dependency_direction,
               :store_handle_leak,
               :record_domain_model,
               :record_codec,
               :foreign_key_model
             ]),
             rules
           )

    assert Enum.all?(violations, fn violation ->
             formatted = Violation.format(violation)
             formatted =~ violation.file and formatted =~ Atom.to_string(violation.rule)
           end)
  end

  test "tracked disposable effects and external secret references are permitted" do
    assert {:ok, []} = Checker.check_sources(fixture_sources("permitted"))
  end

  test "the production scan excludes test directories without hiding runtime violations" do
    assert File.exists?("test/support/graph_store_case.ex")
    assert File.read!("test/support/graph_store_case.ex") =~ "File.rm_rf"
    assert {:ok, []} = Checker.check()
  end

  defp fixture_sources(group) do
    @fixture_root
    |> Path.join(group)
    |> Path.join("*")
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(&{&1, File.read!(&1)})
  end
end
