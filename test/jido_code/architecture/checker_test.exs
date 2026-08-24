defmodule JidoCode.Architecture.CheckerTest do
  use ExUnit.Case, async: true

  alias JidoCode.Architecture.Checker

  test "the tracked application source satisfies the architecture policy" do
    assert {:ok, []} = Checker.check()
  end

  test "rejects parallel persistence and direct store access" do
    sources = [
      {"lib/example/repo.ex", "defmodule Example.Repo do\n  use Ecto.Repo\nend"},
      {"lib/example/resource.ex", "defmodule Example.Resource do\n  use Ash.Resource\nend"},
      {"lib/example/cache.ex",
       "defmodule Example.Cache do\n  def open, do: :dets.open_file(:x, [])\nend"},
      {"lib/example/table.ex",
       "defmodule Example.Table do\n  def open, do: :mnesia.create_table(:x)\nend"},
      {"lib/example/file.ex",
       "defmodule Example.File do\n  def save, do: File.write!(\"state.json\", \"{}\")\nend"},
      {"lib/jido_code_web/raw.ex",
       "defmodule JidoCodeWeb.Raw do\n  def open, do: TripleStore.open(\"state\")\nend"},
      {"lib/jido_code/factory/raw.ex",
       "defmodule JidoCode.Factory.Raw do\n  def open, do: :rocksdb.open(~c\"state\", [])\nend"},
      {"lib/jido_code/knowledge/raw_update.ex",
       "defmodule JidoCode.Knowledge.RawUpdate do\n  def write(store), do: TripleStore.update(store, \"INSERT DATA {}\")\nend"},
      {"lib/jido_code/knowledge/unregistered.ex",
       "defmodule JidoCode.Knowledge.Unregistered do\n  alias JidoCode.Knowledge.WriteBatch\n  def write(quads, options), do: WriteBatch.new(quads, options)\nend"}
    ]

    assert {:error, violations} = Checker.check_sources(sources)
    rules = MapSet.new(violations, & &1.rule)

    assert MapSet.subset?(
             MapSet.new([
               :parallel_persistence,
               :file_persistence,
               :store_ownership,
               :write_coordinator,
               :graph_topology,
               :raw_store_access,
               :raw_rocksdb
             ]),
             rules
           )
  end

  test "enforces plane dependency directions" do
    sources = [
      {"lib/jido_code/factory/leak.ex",
       "defmodule JidoCode.Factory.Leak do\n  alias JidoCode.Knowledge.Internal.Writer\nend"},
      {"lib/jido_code_web/leak.ex",
       "defmodule JidoCodeWeb.Leak do\n  alias JidoCode.Knowledge.StoreServer\nend"},
      {"lib/jido_code/knowledge/leak.ex",
       "defmodule JidoCode.Knowledge.Leak do\n  alias JidoCode.Factory.Scheduler\nend"},
      {"lib/jido_code/integrations/leak.ex",
       "defmodule JidoCode.Integrations.Leak do\n  alias JidoCode.Knowledge.Commands\nend"}
    ]

    assert {:error, violations} = Checker.check_sources(sources)
    assert Enum.count(violations, &(&1.rule == :dependency_direction)) == 4
  end

  test "keeps Jido internals inside the runtime namespace" do
    sources = [
      {"lib/jido_code/knowledge/runtime_leak.ex",
       "defmodule JidoCode.Knowledge.RuntimeLeak do\n  alias Jido.AgentServer\nend"},
      {"lib/jido_code/factory/runtime_leak.ex",
       "defmodule JidoCode.Factory.RuntimeLeak do\n  alias Jido.Signal\nend"},
      {"lib/jido_code_web/runtime_leak.ex",
       "defmodule JidoCodeWeb.RuntimeLeak do\n  alias Jido.Agent\nend"}
    ]

    assert {:error, violations} = Checker.check_sources(sources)
    assert Enum.count(violations, &(&1.rule == :runtime_namespace)) == 3

    assert {:ok, []} =
             Checker.check_sources([
               {"lib/jido_code/runtime/jido_adapter.ex",
                "defmodule JidoCode.Runtime.JidoAdapter do\n  alias Jido.AgentServer\nend"}
             ])
  end

  test "keeps managed runtime persistence ETS-only and unreachable" do
    sources = [
      {"lib/jido_code/runtime/persisted.ex",
       "defmodule JidoCode.Runtime.Persisted do\n  alias Jido.Persist\nend"},
      {"lib/jido_code/runtime/file_store.ex",
       "defmodule JidoCode.Runtime.FileStore do\n  alias Jido.Storage.File\nend"},
      {"lib/jido_code/runtime/thaw.ex",
       "defmodule JidoCode.Runtime.Thaw do\n  def restore(agent), do: JidoCode.Runtime.JidoInstance.thaw(agent)\nend"}
    ]

    assert {:error, violations} = Checker.check_sources(sources)
    assert Enum.count(violations, &(&1.rule == :runtime_persistence)) == 3

    assert {:ok, []} =
             Checker.check_sources([
               {"lib/jido_code/runtime/ephemeral.ex",
                "defmodule JidoCode.Runtime.Ephemeral do\n  alias Jido.Storage.ETS\nend"}
             ])
  end

  test "allows explicit public contracts and owned filesystem roles" do
    sources = [
      {"lib/jido_code/factory/service.ex",
       "defmodule JidoCode.Factory.Service do\n  alias JidoCode.Knowledge.Commands\nend"},
      {"lib/jido_code_web/projection.ex",
       "defmodule JidoCodeWeb.Projection do\n  alias JidoCode.Knowledge.Projections.Repository\nend"},
      {"lib/jido_code/knowledge/store_server.ex",
       "defmodule JidoCode.Knowledge.StoreServer do\n  def open(path), do: TripleStore.open(path, schema: :quad)\nend"},
      {"lib/jido_code/knowledge/backend/checkpoint.ex",
       "defmodule JidoCode.Knowledge.Backend.Checkpoint do\n  @architecture_file_role :graph_backup\n  def save(db, path), do: :rocksdb.checkpoint(db, path)\nend"},
      {"lib/jido_code/runtime/sandbox.ex",
       "defmodule JidoCode.Runtime.Sandbox do\n  @architecture_file_role :temporary\n  def save(path, body), do: File.write!(path, body)\nend"}
    ]

    assert {:ok, []} = Checker.check_sources(sources)
  end

  test "rejects raw SPARQL and record-shaped persistence models" do
    sources = [
      {"lib/jido_code_web/query.ex", ~S|defmodule JidoCodeWeb.Query do
  def query, do: "SELECT ?s WHERE { ?s ?p ?o }"
end|},
      {"lib/example/entity_store.ex", ~S|defmodule Example.EntityStore do
  @derive Jason.Encoder
  defstruct [:repository_id, :owner_id]
  def encode_record(record), do: Jason.encode!(record)
end|},
      {"lib/jido_code/runtime/leaked_handle.ex", ~S|defmodule JidoCode.Runtime.LeakedHandle do
  defstruct [:attempt, :store]
end|}
    ]

    assert {:error, violations} = Checker.check_sources(sources)
    rules = MapSet.new(violations, & &1.rule)

    assert MapSet.subset?(
             MapSet.new([
               :raw_sparql,
               :record_domain_model,
               :foreign_key_model,
               :record_codec,
               :store_handle_leak
             ]),
             rules
           )
  end

  test "limits browser persistence to the theme preference" do
    theme_source = File.read!("assets/js/theme.js")

    assert {:ok, []} =
             Checker.check_sources([
               {"assets/js/theme.js", theme_source}
             ])

    assert {:error, [violation]} =
             Checker.check_sources([
               {"assets/js/session.js", ~S|localStorage.setItem("workflow", "running")|}
             ])

    assert violation.rule == :presentation_persistence

    assert {:error, [violation]} =
             Checker.check_sources([
               {"assets/js/theme.js",
                theme_source <> ~S|\nlocalStorage.setItem("workflow", "running")|}
             ])

    assert violation.rule == :presentation_persistence
  end

  test "bounds reported errors" do
    sources =
      for index <- 1..10 do
        {"lib/example/bad_#{index}.ex",
         "defmodule Example.Bad#{index} do\n  def save, do: File.write!(\"state\", \"x\")\nend"}
      end

    assert {:error, violations} = Checker.check_sources(sources, limit: 3)
    assert length(violations) == 3
  end
end
