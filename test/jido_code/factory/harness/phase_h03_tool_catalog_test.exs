defmodule JidoCode.Factory.Harness.PhaseH03ToolCatalogTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Catalog
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Factory.Tool.RegisteredCommand
  alias JidoCode.Knowledge.ResourceIdentity

  @schema_pins %{
    "search_source" => {
      "sha256:bfe42d6df844a51f9ecdf611d12cbfcf575e4b1cecff1fc3fb16e91834d260b0",
      "sha256:bb18f1a89129c5cb561607c95be05e21fadb69f43e4f1c18727938dc47fd9a0a"
    },
    "inspect_symbol" => {
      "sha256:d447329b6fb7e9d9bf4d64b0db54b6088fc10f5dc6f10e8cd31ec80066333794",
      "sha256:bb18f1a89129c5cb561607c95be05e21fadb69f43e4f1c18727938dc47fd9a0a"
    },
    "read_file" => {
      "sha256:fba95abe33f41a1acb24da2481d3c62da1509e002485821645a06da63dee0653",
      "sha256:bb18f1a89129c5cb561607c95be05e21fadb69f43e4f1c18727938dc47fd9a0a"
    },
    "apply_edit" => {
      "sha256:3353d0619140ac37f2ed68eb2142fa6b3835df803e495baee2816d6ea60256fc",
      "sha256:33a00d40ddc77177ddcdfc5ebccd5607f0d879c5fefa4099ad3745876b12c6ac"
    },
    "create_file" => {
      "sha256:66c65761b5af89932dc1a2196169120ea1fe5c8df13aab1817a234556884351c",
      "sha256:33a00d40ddc77177ddcdfc5ebccd5607f0d879c5fefa4099ad3745876b12c6ac"
    },
    "delete_file" => {
      "sha256:2612347acb2120ee10ac3afabb6ce5c3419655de1177c0eb5ffa8b604807ac8b",
      "sha256:33a00d40ddc77177ddcdfc5ebccd5607f0d879c5fefa4099ad3745876b12c6ac"
    },
    "run_registered_check" => {
      "sha256:be9d87d2421614573290ae73212327ba178442c3f259a16be9668eb635f9ae69",
      "sha256:f983fdb597e22ecfb7a27a492d7e20fe197e65679796400b0816690401881893"
    },
    "run_governed_command" => {
      "sha256:31d8174f18dca8a76e2c458574255c6f531d20cdc72bd37e7a8f47b58f70fd61",
      "sha256:f983fdb597e22ecfb7a27a492d7e20fe197e65679796400b0816690401881893"
    },
    "show_candidate_diff" => {
      "sha256:74b555d2b2d0a94f10e4e382d099de46d818c2a388b49bbe6ee503522a8d58cc",
      "sha256:bb18f1a89129c5cb561607c95be05e21fadb69f43e4f1c18727938dc47fd9a0a"
    },
    "submit_candidate" => {
      "sha256:b6b2533cf4aa9698542b3a10d151c783951219bdd5bc3d539cd9e971f90012e4",
      "sha256:19ff83049e2dd788f2208d727f5adbb030fa3afca0224f1f8eac9998270ce500"
    },
    "request_clarification" => {
      "sha256:0113e3a9d92bd90862aa3558a551971e166f5908995eca864e6e71a3a0f76f66",
      "sha256:184dc716b0c9dcb3ebdf563924c68a6fa7fe51ada1ce81ca5624f25e64beb04b"
    }
  }

  test "pins the exact initial tool set, versions, schemas, and adapter identities" do
    definitions = Catalog.all()

    assert Enum.map(definitions, & &1.name) == Catalog.names()
    assert MapSet.size(MapSet.new(Enum.map(definitions, & &1.iri))) == 11

    for %Definition{} = definition <- definitions do
      assert definition.version == "1.0.0"

      assert {definition.input_schema_digest, definition.output_schema_digest} ==
               Map.fetch!(@schema_pins, definition.name)

      assert definition.adapter_digest == Definition.digest(definition.adapter_identity)
      assert definition.input_schema.additional_properties == false
      assert definition.safe_errors != []
    end

    expected_model_keys =
      MapSet.new([:description, :input_schema, :input_schema_digest, :name, :version])

    assert Enum.all?(Catalog.model_tools(), &(MapSet.new(Map.keys(&1)) == expected_model_keys))
  end

  test "records complete effect, retry, approval, and supply-chain policy" do
    for definition <- Catalog.all() do
      assert definition.capability
      assert definition.effect_class in [:read, :write, :external, :publish]
      assert definition.preconditions != []
      assert definition.reversibility in [:none, :compensating, :reversible, :not_applicable]
      assert definition.retry_policy in [:never, :safe_idempotent, :reconcile_first]
      assert definition.idempotency_policy in [:read_only, :required, :external_effect_id]
      assert definition.timeout_ms <= 300_000
      assert definition.max_output_bytes <= 1_048_576
    end

    assert {:ok, governed} = Catalog.fetch("run_governed_command")
    assert governed.approval_required
    assert governed.input_schema.properties == %{command: {:string, 64}}
    refute "shell" in Catalog.names()

    assert {:ok, submit} = Catalog.fetch("submit_candidate")
    assert submit.approval_required
    assert submit.retry_policy == :reconcile_first
    assert submit.idempotency_policy == :external_effect_id
    assert submit.network_policy == {:allowlist, ["https://api.github.com"]}
  end

  test "closed-validates a representative call for every catalog tool" do
    for {name, arguments} <- valid_arguments() do
      assert {:ok, {%Definition{name: ^name}, normalized}} =
               Catalog.validate(name, "1.0.0", stringify_keys(arguments), constraints())

      assert normalized == arguments
    end
  end

  test "rejects unknown properties and incomplete calls for every tool" do
    for {name, arguments} <- valid_arguments() do
      assert {:error, %AdapterError{operation: :tool_input}} =
               Catalog.validate(
                 name,
                 "1.0.0",
                 Map.put(arguments, :unknown, "scope expansion"),
                 constraints()
               )

      required = Catalog.fetch(name) |> elem(1) |> then(& &1.input_schema.required)
      incomplete = Map.delete(arguments, List.first(required))

      assert {:error, %AdapterError{operation: :tool_input}} =
               Catalog.validate(name, "1.0.0", incomplete, constraints())
    end
  end

  test "rejects path traversal, absolute paths, and non-normalized paths" do
    for path <- ["../secrets", "/etc/passwd", "lib/../config", "lib//hidden", "lib\\hidden"] do
      arguments = Map.put(valid_arguments()["read_file"], :path, path)

      assert {:error, %AdapterError{operation: :tool_input}} =
               Catalog.validate("read_file", "1.0.0", arguments, constraints())
    end

    outside_scope = Map.put(valid_arguments()["create_file"], :path, "priv/hidden.ex")

    assert {:error, %AdapterError{operation: :tool_input}} =
             Catalog.validate("create_file", "1.0.0", outside_scope, constraints())
  end

  test "rejects ambiguous edits, unauthorized refs, commands, and destinations" do
    ambiguous =
      valid_arguments()["apply_edit"]
      |> Map.put(:expected_matches, 2)

    assert {:error, %AdapterError{operation: :tool_input}} =
             Catalog.validate("apply_edit", "1.0.0", ambiguous, constraints())

    unauthorized_ref =
      valid_arguments()["inspect_symbol"]
      |> Map.put(:source_ref, resource!("unauthorized"))

    assert {:error, %AdapterError{operation: :tool_input}} =
             Catalog.validate("inspect_symbol", "1.0.0", unauthorized_ref, constraints())

    command = Map.put(valid_arguments()["run_registered_check"], :check, "raw-shell")

    assert {:error, %AdapterError{operation: :tool_input}} =
             Catalog.validate("run_registered_check", "1.0.0", command, constraints())

    destination = Map.put(valid_arguments()["submit_candidate"], :destination, "public-webhook")

    assert {:error, %AdapterError{operation: :tool_input}} =
             Catalog.validate("submit_candidate", "1.0.0", destination, constraints())
  end

  test "registered commands keep executable, cwd, arguments, environment, network, and limits server-owned" do
    attributes = %{
      name: "mix-test",
      executable: "/usr/bin/env",
      working_directory: :repository_root,
      arguments: ["mix", "test"],
      environment: %{"MIX_ENV" => "test"},
      network_policy: :deny,
      resource_limits: %{
        cpu_ms: 300_000,
        memory_bytes: 1_073_741_824,
        timeout_ms: 300_000,
        output_bytes: 131_072
      }
    }

    assert {:ok, %RegisteredCommand{} = command} = RegisteredCommand.new(attributes)
    refute inspect(command) =~ "/usr/bin/env"
    refute inspect(command) =~ "mix test"

    for mutation <- [
          %{attributes | executable: "sh"},
          %{attributes | working_directory: "/tmp"},
          %{attributes | environment: %{"API_TOKEN" => "credential"}},
          %{attributes | network_policy: :allow},
          %{attributes | resource_limits: %{timeout_ms: 1}}
        ] do
      assert {:error, %AdapterError{operation: :registered_command}} =
               RegisteredCommand.new(mutation)
    end
  end

  test "schema and adapter digests cannot drift without contract replacement" do
    definition = List.first(Catalog.all())

    assert {:error, %AdapterError{operation: :tool_definition}} =
             definition
             |> Map.from_struct()
             |> put_in([:input_schema, :properties, :extra], {:string, 10})
             |> Definition.new()

    assert {:error, %AdapterError{operation: :tool_definition}} =
             definition
             |> Map.from_struct()
             |> Map.put(:adapter_identity, "JidoCode.Factory.Tools.Unreviewed/1")
             |> Definition.new()
  end

  defp valid_arguments do
    digest = "sha256:" <> String.duplicate("a", 64)

    %{
      "search_source" => %{query: "ToolRunner", scope_ref: resource!("scope")},
      "inspect_symbol" => %{
        symbol: "JidoCode.Factory.ToolRunner.execute/4",
        source_ref: resource!("source"),
        expected_revision: 7
      },
      "read_file" => %{path: "lib/jido_code.ex", expected_digest: digest},
      "apply_edit" => %{
        path: "lib/jido_code.ex",
        expected_digest: digest,
        old_text: "old",
        new_text: "new",
        expected_matches: 1
      },
      "create_file" => %{
        path: "test/new_test.exs",
        content: "defmodule NewTest do\nend\n",
        expected_parent_digest: digest
      },
      "delete_file" => %{path: "test/obsolete_test.exs", expected_digest: digest},
      "run_registered_check" => %{check: "mix-test"},
      "run_governed_command" => %{command: "format-check"},
      "show_candidate_diff" => %{snapshot_ref: resource!("snapshot")},
      "submit_candidate" => %{
        candidate_ref: resource!("candidate"),
        approval_ref: resource!("approval"),
        destination: "github_pull_request",
        expected_revision: 12
      },
      "request_clarification" => %{
        question: "Which target branch should receive this candidate?",
        reason: "ambiguous_intent"
      }
    }
  end

  defp constraints do
    %{
      allowed_path_prefixes: ["lib", "test"],
      allowed_refs: [
        resource!("scope"),
        resource!("source"),
        resource!("snapshot"),
        resource!("candidate"),
        resource!("approval")
      ],
      allowed_destinations: ["github_pull_request"],
      registered_commands: ["mix-test", "format-check"]
    }
  end

  defp stringify_keys(arguments),
    do: Map.new(arguments, fn {key, value} -> {Atom.to_string(key), value} end)

  defp resource!(seed) do
    {:ok, iri} = ResourceIdentity.deterministic(:knowledge_assertion, "phase-h03-#{seed}")
    iri
  end
end
