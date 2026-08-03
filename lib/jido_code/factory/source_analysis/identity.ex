defmodule JidoCode.Factory.SourceAnalysis.Identity do
  @moduledoc "Public identity-policy bridge used by source analyzer adapters."

  alias JidoCode.Knowledge

  def artifact(snapshot_iri, path, digest),
    do: Knowledge.source_artifact_identity(snapshot_iri, path, digest)

  def symbol(snapshot_iri, kind, name),
    do: Knowledge.code_symbol_identity(snapshot_iri, kind, name)

  def activity(snapshot_iri, analyzer_version, configuration_digest),
    do: Knowledge.source_analysis_identity(snapshot_iri, analyzer_version, configuration_digest)
end
