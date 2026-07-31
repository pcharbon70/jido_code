defmodule JidoCode.TestSupport.GraphFixtures do
  @moduledoc false

  @fixture_path Path.expand("../fixtures/graph/compatibility.trig", __DIR__)
  @external_resource @fixture_path
  @compatibility_sha256 "e579a91e4b5dbb7c483bc664510d34580418ae7aafac2e17832507928be0e0f9"

  def compatibility_trig! do
    contents = File.read!(@fixture_path)
    actual = :crypto.hash(:sha256, contents) |> Base.encode16(case: :lower)

    if actual != @compatibility_sha256 do
      raise "RDF fixture digest mismatch: expected #{@compatibility_sha256}, got #{actual}"
    end

    contents
  end

  def compatibility_sha256, do: @compatibility_sha256
end
