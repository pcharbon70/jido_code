defmodule JidoCode.TestSupport.FakeProductCommandGateway do
  @moduledoc false

  def enroll_repository(authority, identity, params) do
    send(
      Application.fetch_env!(:jido_code, :product_projection_test_pid),
      {:enroll_repository, authority, identity, params}
    )

    Application.fetch_env!(:jido_code, :product_command_fixture)
  end
end
