defmodule JidoCode.Knowledge.RepositoryWiki.MixReconcilerTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.LockParser
  alias JidoCode.Knowledge.RepositoryWiki.MixReconciler
  alias JidoCode.Knowledge.RepositoryWiki.MixStatic

  @source ~S'''
  defmodule Demo.MixProject do
    def project do
      [app: :demo, version: "1.0.0", elixirc_paths: paths(Mix.env()), deps: [{:alpha, "~> 1.0"}]]
    end
  end
  '''
  @checksum String.duplicate("a", 64)
  @outer_checksum String.duplicate("b", 64)

  setup do
    {:ok, static} = MixStatic.extract(@source)

    {:ok, lock} =
      LockParser.parse("""
      %{"alpha" => {:hex, :alpha, "1.2.0", "#{@checksum}", [:mix], [], "hexpm", "#{@outer_checksum}"}}
      """)

    attributes = %{
      source_digest: static.source_digest,
      lock_digest: lock.source_digest,
      source_fence: "git:sha256:#{digest("source")}",
      toolchain_digest: "sha256:#{digest("toolchain")}",
      policy_revision: 4
    }

    observation = observation(static, attributes, false)
    %{static: static, lock: lock, attributes: attributes, observation: observation}
  end

  test "reconciles declared, locked, observed, and accepted facts with provenance", context do
    accepted = [
      %{
        name: "repository.default_branch",
        value: "main",
        source_fence: context.attributes.source_fence,
        source_digest: digest("accepted"),
        revision: 9,
        freshness: :fresh
      }
    ]

    assert {:ok, result} =
             MixReconciler.reconcile(
               context.static,
               context.lock,
               context.observation,
               accepted,
               context.attributes
             )

    assert result.profile == "mix-reconcile/1.0.0"
    assert result.profile_digest == MixReconciler.profile().digest
    assert result.parser_profile_digest == context.static.profile_digest
    assert result.lock_profile_digest == context.lock.profile_digest
    assert result.completeness.state == :complete
    assert result.model_calls == 0
    assert result.declared_dependencies |> hd() |> Map.fetch!(:name) == "alpha"
    assert result.lock_entries |> hd() |> Map.fetch!(:version) == "1.2.0"

    assert field(result, "app").state == :declared
    assert field(result, "app").value == "demo"
    assert field(result, "elixirc_paths").state == :observed
    assert field(result, "elixirc_paths").value == ["lib"]
    assert field(result, "repository.default_branch").state == :accepted

    assert Enum.all?(field(result, "elixirc_paths").candidates, fn candidate ->
             candidate.source_kind in [:mix_exs, :sandbox_observation] and
               candidate.freshness == :fresh and candidate.conflict_state == :none
           end)
  end

  test "retains conflicting source and accepted graph values instead of flattening them",
       context do
    accepted = [
      %{
        name: "version",
        value: "9.9.9",
        source_fence: context.attributes.source_fence,
        source_digest: digest("accepted-conflict"),
        revision: 1
      }
    ]

    assert {:ok, result} =
             MixReconciler.reconcile(
               context.static,
               context.lock,
               context.observation,
               accepted,
               context.attributes
             )

    version = field(result, "version")
    assert version.state == :conflicting
    assert version.value == nil
    assert Enum.map(version.candidates, & &1.value) |> Enum.sort() == ["1.0.0", "9.9.9"]
    assert result.completeness.state == :partial
    assert result.completeness.conflict_count == 1
    assert %{kind: :conflicting, field: "version", blocking: true} in result.gaps
  end

  test "surfaces missing, truncated, unsupported, and unavailable inputs as gaps", context do
    assert {:ok, missing} =
             MixReconciler.reconcile(
               context.static,
               nil,
               nil,
               [],
               Map.put(context.attributes, :lock_digest, nil)
             )

    assert Enum.any?(missing.gaps, &(&1.kind == :missing_lock and &1.blocking))
    assert Enum.any?(missing.gaps, &(&1.kind == :missing_observation and &1.blocking))

    truncated = observation(context.static, context.attributes, true)

    assert {:ok, partial} =
             MixReconciler.reconcile(
               context.static,
               context.lock,
               truncated,
               [],
               context.attributes
             )

    assert Enum.any?(partial.gaps, &(&1.kind == :truncated_observation and &1.blocking))
    assert partial.completeness.state == :partial
  end

  test "rejects late observations and accepted facts from another source fence", context do
    stale = %{context.observation | source_digest: digest("stale")}

    assert {:error, %{kind: :conflict}} =
             MixReconciler.reconcile(
               context.static,
               context.lock,
               stale,
               [],
               context.attributes
             )

    accepted = [
      %{
        name: "version",
        value: "1.0.0",
        source_fence: "git:sha256:#{digest("other")}",
        source_digest: digest("accepted"),
        revision: 1
      }
    ]

    assert {:error, %{kind: :invalid_input}} =
             MixReconciler.reconcile(
               context.static,
               context.lock,
               context.observation,
               accepted,
               context.attributes
             )
  end

  defp observation(static, attributes, truncated) do
    value = %{
      profile: "mix-sandbox/1.0.0",
      profile_digest: "sha256:#{digest("sandbox-profile")}",
      source_digest: static.source_digest,
      source_fence: attributes.source_fence,
      toolchain_digest: attributes.toolchain_digest,
      policy_revision: attributes.policy_revision,
      fields: [
        %{
          name: "elixirc_paths",
          value: ["lib"],
          state: :observed,
          authority: :observed
        }
      ],
      dependencies: [],
      status: :completed,
      truncated: truncated
    }

    Map.put(value, :digest, Contract.digest(value))
  end

  defp field(result, name), do: Enum.find(result.fields, &(&1.name == name))
  defp digest(seed), do: :crypto.hash(:sha256, seed) |> Base.encode16(case: :lower)
end
