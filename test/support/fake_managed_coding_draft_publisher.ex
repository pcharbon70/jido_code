defmodule JidoCode.TestSupport.FakeManagedCodingDraftPublisher do
  @behaviour JidoCode.Factory.Ports.ManagedCodingDraftPublisher

  def create_draft(owner, request, options) do
    send(owner, {:draft_publication, request, options})
    {:ok, %{branch: "agent/draft-candidate", pull_request: 101, draft: true}}
  end
end
