defmodule JidoCode.TestSupport.FakeRepositoryWikiProjectionProvider do
  @moduledoc false

  def load(authority, identity, options) do
    if test_pid = Application.get_env(:jido_code, :product_projection_test_pid) do
      send(test_pid, {:repository_wiki_projection_load, authority, identity, options})
    end

    {:ok, Application.fetch_env!(:jido_code, :repository_wiki_projection_fixture)}
  end
end
