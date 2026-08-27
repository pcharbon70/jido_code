defmodule JidoCode.TestSupport.FakeProductCommandGateway do
  @moduledoc false

  def enroll_repository(authority, identity, params) do
    send(
      Application.fetch_env!(:jido_code, :product_projection_test_pid),
      {:enroll_repository, authority, identity, params}
    )

    Application.fetch_env!(:jido_code, :product_command_fixture)
  end

  def configure_repository_wiki(authority, identity, repository, params) do
    send(
      Application.fetch_env!(:jido_code, :product_projection_test_pid),
      {:configure_repository_wiki, authority, identity, repository, params}
    )

    Application.fetch_env!(:jido_code, :product_command_fixture)
  end

  def regenerate_repository_wiki(authority, identity, repository) do
    send(
      Application.fetch_env!(:jido_code, :product_projection_test_pid),
      {:regenerate_repository_wiki, authority, identity, repository}
    )

    Application.fetch_env!(:jido_code, :product_command_fixture)
  end
end
