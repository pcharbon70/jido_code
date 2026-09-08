defmodule JidoCode.Architecture.HypermediaUIPhaseD4Test do
  use ExUnit.Case, async: true
  alias JidoCode.Architecture.HypermediaUIPhaseD4, as: Phase

  test "dependency candidate admits only the exact TripleStore pin replacement" do
    for path <- ~w[mix.exs mix.lock] do
      body = File.read!(path)
      assert Phase.dependency_input_valid?(path, body)
      refute Phase.dependency_input_valid?(path, body <> "\n# unrelated change\n")

      refute Phase.dependency_input_valid?(
               path,
               String.replace(body, "c243be84decaeaa744d509fbfa8e07c10e2a0988", "main")
             )

      refute Phase.dependency_input_valid?(
               path,
               String.replace(body, "phoenix", "unreviewed_dependency")
             )
    end

    refute Phase.dependency_input_valid?("unregistered", "anything")
    assert Phase.dependency_digest(File.cwd!(), "unregistered") == nil
  end

  test "candidate source inventory and predecessor evidence remain exact" do
    assert {:ok, []} = Phase.check()
    {:ok, evidence} = Phase.load()

    for {key, value} <- [
          {"source_digests", %{}},
          {"predecessor_source_digests", %{}},
          {"baseline_commit", "wrong"},
          {"status", "accepted_at_merged_candidate"},
          {"completed_sections", ["4.1"]},
          {"independent_reviews", "self-approved"},
          {"browser_toolchain", "1.62.0"},
          {"triple_store_candidate", "6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f"},
          {"merged_candidate", "invented"}
        ] do
      refute Phase.validate(Map.put(evidence, key, value), File.cwd!()) == []
    end
  end
end
