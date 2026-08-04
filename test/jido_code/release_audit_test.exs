defmodule JidoCode.ReleaseAuditTest do
  use ExUnit.Case, async: true

  alias JidoCode.ReleaseAudit

  test "accepts one graph store and traces representative facts through semantic commands" do
    assert {:ok, audit} = ReleaseAudit.run()
    assert audit.status == :accepted
    assert audit.durable_store_count == 1
    assert audit.durable_store == :triple_store
    assert audit.hidden_authority_findings == 0
    assert audit.compatibility_facades == 0
    assert audit.source_file_count > 100
    assert byte_size(audit.source_manifest_sha256) == 64
    assert length(audit.representative_traces) == 5
    assert Enum.all?(audit.representative_traces, &is_binary(&1.command))
  end
end
