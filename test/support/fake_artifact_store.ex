defmodule JidoCode.TestSupport.FakeArtifactStore do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ArtifactStore

  @impl true
  def put(%{owner: owner}, request) do
    send(owner, {:artifact_store_put, request})
    digest = String.replace_prefix(request.content_digest, "sha256:", "")
    {:ok, "https://artifacts.jido.run/immutable/#{digest}"}
  end
end
