defmodule JidoCode.Knowledge.RepositoryWiki.HistoryRetentionTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge

  @now ~U[2026-08-27 16:00:00Z]

  test "separates retained history from disposable preview and render artifacts" do
    classes = Knowledge.repository_wiki_retention_classes()
    policy = %{classes: classes |> Map.keys() |> Enum.sort(), retain_superseded?: true}
    repository = "https://jido.run/id/repository/history"

    resources = [
      resource(repository, "current", :current, nil, selected?: true),
      resource(repository, "superseded", :superseded, nil),
      resource(repository, "preview", :preview, DateTime.add(@now, -1, :second)),
      resource(repository, "render", :render_artifact, DateTime.add(@now, -1, :second)),
      resource(repository, "rejected", :rejected, DateTime.add(@now, -1, :second)),
      resource(repository, "audit", :audit, nil, immutable_evidence?: true),
      resource(repository, "cited-source", :source_snapshot, nil, cited?: true)
    ]

    assert {:ok, plan} = Knowledge.plan_repository_wiki_retention(resources, @now, policy)
    actions = Map.new(plan.actions, &{&1.iri, &1.action})

    assert actions[iri("current")] == :retain
    assert actions[iri("superseded")] == :retain
    assert actions[iri("preview")] == :delete_disposable
    assert actions[iri("render")] == :delete_disposable
    assert actions[iri("rejected")] == :compact_keep_tombstone
    assert actions[iri("audit")] == :retain
    assert actions[iri("cited-source")] == :retain
    assert plan.deletion_count == 2
    assert plan.compaction_count == 1
    assert plan.immutable_evidence_preserved?
    refute plan.current_restoration_authority?
  end

  test "never deletes selected, cited, release-required, or immutable evidence" do
    classes = Knowledge.repository_wiki_retention_classes()
    policy = %{classes: classes |> Map.keys() |> Enum.sort(), retain_superseded?: false}
    repository = "https://jido.run/id/repository/protected-history"
    expired = DateTime.add(@now, -60, :second)

    resources = [
      resource(repository, "selected-preview", :preview, expired, selected?: true),
      resource(repository, "cited-preview", :preview, expired, cited?: true),
      resource(repository, "release-preview", :preview, expired, required_release?: true),
      resource(repository, "audit-preview", :preview, expired, immutable_evidence?: true)
    ]

    assert {:ok, plan} = Knowledge.plan_repository_wiki_retention(resources, @now, policy)
    assert Enum.all?(plan.actions, &(&1.action == :retain))
    assert Enum.all?(plan.actions, & &1.immutable_evidence_preserved?)
  end

  test "retained history has no direct current restoration authority" do
    refute JidoCode.Knowledge.RepositoryWiki.Retention.restorable_as_current?(
             %{class: :superseded, edition_iri: iri("old")},
             %{repository_iri: "https://jido.run/id/repository/history"}
           )
  end

  defp resource(repository, seed, class, expires_at, options \\ []) do
    %{
      iri: iri(seed),
      repository_iri: repository,
      class: class,
      expires_at: expires_at,
      selected?: Keyword.get(options, :selected?, false),
      cited?: Keyword.get(options, :cited?, false),
      required_release?: Keyword.get(options, :required_release?, false),
      immutable_evidence?: Keyword.get(options, :immutable_evidence?, false),
      cache_namespace: "cache-#{seed}"
    }
  end

  defp iri(seed), do: "https://jido.run/id/wiki-history/#{seed}"
end
