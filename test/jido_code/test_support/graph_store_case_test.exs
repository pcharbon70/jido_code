defmodule JidoCode.TestSupport.GraphStoreCaseTest do
  use JidoCode.GraphStoreCase

  alias JidoCode.TestSupport.DeterministicIdentity
  alias JidoCode.TestSupport.FixedClock
  alias JidoCode.TestSupport.GraphFixtures
  alias JidoCode.TestSupport.SeededConcurrency

  test "provides one isolated quad store and bounded path diagnostics", %{
    root: root,
    store: store
  } do
    assert store.schema == :quad
    assert String.starts_with?(root, Path.join(System.tmp_dir!(), "jido_code_graph_store_cases"))
    assert Enum.any?(directory_snapshot(root), &(&1.path == "store"))
  end

  test "provides deterministic clock, identity, fixture, and concurrency inputs" do
    assert FixedClock.now() == ~U[2026-01-15 12:00:00Z]
    assert FixedClock.now(60) == ~U[2026-01-15 12:01:00Z]

    assert DeterministicIdentity.iri("commands", 1, seed: 7) ==
             DeterministicIdentity.iri("commands", 1, seed: 7)

    refute DeterministicIdentity.iri("commands", 1, seed: 7) ==
             DeterministicIdentity.iri("commands", 1, seed: 8)

    assert :crypto.hash(:sha256, GraphFixtures.compatibility_trig!())
           |> Base.encode16(case: :lower) == GraphFixtures.compatibility_sha256()

    first = SeededConcurrency.run(1..8, &(&1 * 2), seed: 17, max_concurrency: 3)
    second = SeededConcurrency.run(1..8, &(&1 * 2), seed: 17, max_concurrency: 3)

    assert first == second
    assert Enum.all?(first, &match?({:ok, value} when is_integer(value), &1))
  end

  test "rejects async real-store cases at macro expansion" do
    assert_raise ArgumentError, ~r/real graph-store cases must run with async: false/, fn ->
      Code.compile_string("""
      defmodule JidoCode.TestSupport.InvalidAsyncGraphStoreCase do
        use JidoCode.GraphStoreCase, async: true
      end
      """)
    end
  end
end
