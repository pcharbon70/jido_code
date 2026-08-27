defmodule JidoCode.Knowledge.RepositoryWiki.MixStaticTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.MixStatic

  @literal_project ~S'''
  defmodule Demo.MixProject do
    use Mix.Project

    def project do
      [
        app: :demo,
        version: "1.2.3",
        elixir: "~> 1.19",
        elixirc_paths: paths(Mix.env()),
        start_permanent: System.get_env("START") == "1",
        aliases: aliases(),
        deps: deps()
      ]
    end

    def application do
      [mod: {Demo.Application, []}, extra_applications: [:logger, :runtime_tools]]
    end

    def cli do
      [preferred_envs: [precommit: :test]]
    end

    defp deps do
      [
        {:alpha, "~> 1.0", only: [:dev, :test], optional: true, runtime: false},
        {:local_child, path: "apps/local_child", override: true},
        {:source_dep, git: "https://example.invalid/source.git", ref: "0123456789abcdef"}
      ]
    end

    defp aliases do
      [precommit: ["compile", "test"], setup: "deps.get"]
    end

    defp paths(_environment), do: ["lib"]
  end
  '''

  test "extracts literal project, application, alias, CLI, and dependency facts deterministically" do
    assert {:ok, first} = MixStatic.extract(@literal_project)
    assert {:ok, second} = MixStatic.extract(@literal_project)

    assert first == second
    assert first.profile == "mix-static/1.0.0"
    assert first.digest == second.digest
    assert first.dependency_count == 3
    assert first.model_calls == 0
    assert first.model_input_tokens == 0
    assert first.model_output_tokens == 0
    assert first.usage_cost_microunits == 0

    assert field(first, "app").value == "demo"
    assert field(first, "version").value == "1.2.3"
    assert field(first, "application.mod").value == %{tuple: ["Demo.Application", []]}
    assert field(first, "application.extra_applications").value == ["logger", "runtime_tools"]
    assert field(first, "cli.preferred_envs").value == %{"precommit" => "test"}
    assert field(first, "aliases").value == ["precommit", "setup"]

    alpha = dependency(first, "alpha")
    assert alpha.requirement == "~> 1.0"
    assert alpha.environments == ["dev", "test"]
    assert alpha.optional
    refute alpha.runtime
    assert alpha.location.line == 26

    local = dependency(first, "local_child")
    assert local.scm == "path"
    assert local.options["path"] == "apps/local_child"
    assert local.override

    git = dependency(first, "source_dep")
    assert git.scm == "git"
    assert git.options["ref"] == "0123456789abcdef"
  end

  test "keeps calls, environment reads, and other expressions unresolved without executing them" do
    marker =
      Path.join(
        System.tmp_dir!(),
        "jido-wiki-mix-static-#{System.unique_integer([:positive])}"
      )

    source = """
    defmodule Hostile.MixProject do
      def project do
        [
          app: :hostile,
          version: File.write!(#{inspect(marker)}, "executed"),
          elixir: System.get_env("SECRET"),
          deps: if(true, do: raise("executed"), else: [])
        ]
      end
    end
    """

    refute File.exists?(marker)
    assert {:ok, result} = MixStatic.extract(source)
    refute File.exists?(marker)

    assert field(result, "app").state == :static_exact
    assert field(result, "version").state == :dynamic_required
    assert field(result, "elixir").state == :dynamic_required
    assert field(result, "deps").state == :dynamic_required
    assert result.dependencies == []
    assert result.coverage.dynamic_required == 3
  end

  test "does not intern repository-controlled atom literals" do
    atom_name = "wiki_atom_that_must_not_exist_427019864"
    assert_raise ArgumentError, fn -> String.to_existing_atom(atom_name) end

    source = "defmodule Demo.MixProject do\n def project, do: [app: :#{atom_name}]\nend\n"
    assert {:ok, result} = MixStatic.extract(source)
    assert field(result, "app").value == atom_name

    assert_raise ArgumentError, fn -> String.to_existing_atom(atom_name) end
  end

  test "rejects malformed syntax, traversal paths, duplicate dependency names, and raised limits" do
    assert {:error, %{kind: :invalid_input}} = MixStatic.extract("defmodule [")

    assert {:error, %{kind: :invalid_input}} =
             MixStatic.extract(@literal_project, %{source_path: "../mix.exs"})

    duplicate = """
    defmodule Demo.MixProject do
      def project, do: [app: :demo, deps: deps()]
      defp deps, do: [{:same, "~> 1.0"}, {:same, "~> 2.0"}]
    end
    """

    assert {:error, %{kind: :invalid_input}} = MixStatic.extract(duplicate)

    limits = %{MixStatic.profile().limits | source_bytes: 32}

    assert {:error, %{kind: :invalid_input}} =
             MixStatic.extract(@literal_project, %{limits: limits})

    raised = %{MixStatic.profile().limits | dependencies: 513}

    assert {:error, %{kind: :invalid_input}} =
             MixStatic.extract(@literal_project, %{limits: raised})
  end

  test "parses this repository project without executing it and reports dynamic coverage" do
    assert {:ok, result} = MixStatic.extract(File.read!("mix.exs"))
    assert result.dependency_count > 20
    assert field(result, "app").value == "jido_code"
    assert field(result, "version").value == "0.1.0"
    assert field(result, "elixirc_paths").state == :dynamic_required
    assert field(result, "start_permanent").state == :dynamic_required
    assert dependency(result, "req").requirement == "~> 0.6.1"
  end

  defp field(result, name), do: Enum.find(result.fields, &(&1.name == name))
  defp dependency(result, name), do: Enum.find(result.dependencies, &(&1.name == name))
end
