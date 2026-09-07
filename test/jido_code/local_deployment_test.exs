defmodule JidoCode.LocalDeploymentTest do
  use ExUnit.Case, async: true
  alias JidoCode.LocalDeployment

  test "production profile is direct loopback HTTP/1 with bounded sockets and no compression" do
    assert {:ok, config} = LocalDeployment.transport(%{})
    assert config[:url] == [host: "127.0.0.1", port: 4000, scheme: "http"]
    assert config[:check_origin] == ["http://127.0.0.1:4000"]
    assert config[:http][:ip] == {127, 0, 0, 1}
    assert config[:http][:http_options][:compress] == false
    assert config[:http][:http_2_options][:enabled] == false
    assert config[:http][:thousand_island_options][:num_acceptors] == 4
    assert config[:http][:thousand_island_options][:num_connections] == 32
    assert config[:http][:thousand_island_options][:transport_options][:send_timeout] == 2_000
  end

  test "unsupported exposure, clustering and malformed ports fail closed" do
    for env <- [
          %{"PHX_HOST" => "example.com"},
          %{"PHX_HOST" => "0.0.0.0"},
          %{"PHX_HOST" => "[::]"},
          %{"DNS_CLUSTER_QUERY" => "cluster.local"},
          %{"JIDO_CODE_DEPLOYMENT_PROFILE" => "public"},
          %{"PORT" => "4000trailing"},
          %{"PORT" => "0"},
          %{"PORT" => "65536"}
        ] do
      assert {:error, :unsupported_local_deployment} = LocalDeployment.transport(env)
    end
  end

  test "explicit localhost origin retains the chosen nonprivileged port" do
    assert {:ok, config} =
             LocalDeployment.transport(%{"PHX_HOST" => "localhost", "PORT" => "4400"})

    assert config[:url] == [host: "localhost", port: 4400, scheme: "http"]
    assert config[:http][:ip] == {127, 0, 0, 1}
  end
end
