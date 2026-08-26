defmodule JidoCode.Knowledge.RepositoryWiki.Protocol do
  @moduledoc "Pinned repository-wiki semantic and deterministic compiler identities."

  @semantic_version "2.10.0"
  @ontology_version "1.5.0"
  @compiler_profile "wiki-deterministic-elixir/1.0.0"
  @compiler_digest :crypto.hash(:sha256, @compiler_profile) |> Base.encode16(case: :lower)
  @profile_keys [:manual_deterministic, :automatic_deterministic]
  @reserved_commands [
    "AcquireWikiMaintainerLease",
    "ReserveWikiModelBudget",
    "RecordWikiModelUsage",
    "InvokeWikiSynthesis"
  ]

  def semantic_version, do: @semantic_version
  def ontology_version, do: @ontology_version
  def compiler_profile, do: @compiler_profile
  def compiler_digest, do: @compiler_digest
  def profile_keys, do: @profile_keys
  def reserved_commands, do: @reserved_commands
end
