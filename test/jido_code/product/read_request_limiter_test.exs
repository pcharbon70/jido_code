defmodule JidoCode.Product.ReadRequestLimiterTest do
  use ExUnit.Case, async: true
  alias JidoCode.Product.ReadRequestLimiter, as: Limiter

  setup do
    server = start_supervised!({Limiter, name: __MODULE__})
    %{server: server}
  end

  test "caps a principal across sessions and releases concurrent leases", %{server: server} do
    {:ok, one} = Limiter.acquire("same-human", server)
    {:ok, two} = Limiter.acquire("same-human", server)
    assert {:error, :rate_limited} = Limiter.acquire("same-human", server)
    Limiter.release(one, server)
    Limiter.release(two, server)

    for _ <- 1..28 do
      assert {:ok, lease} = Limiter.acquire("same-human", server)
      Limiter.release(lease, server)
    end

    assert {:error, :rate_limited} = Limiter.acquire("same-human", server)
    assert {:ok, _lease} = Limiter.acquire("other-human", server)
  end

  test "caps global work, cleans up dead owners and expires bounded rate windows", %{
    server: server
  } do
    leases =
      for i <- 1..16 do
        {:ok, lease} = Limiter.acquire("human-#{i}", server)
        lease
      end

    assert {:error, :rate_limited} = Limiter.acquire("overflow", server)
    Enum.each(leases, &Limiter.release(&1, server))
    task = Task.async(fn -> Limiter.acquire("departed", server) end)
    {:ok, lease} = Task.await(task)
    assert_released(server, lease, 10)

    :sys.replace_state(server, fn state ->
      %{state | windows: %{"expired" => {System.monotonic_time(:millisecond) - 60_001, 30}}}
    end)

    assert {:ok, _lease} = Limiter.acquire("expired", server)
  end

  test "bounds distinct principal windows and fails closed for invalid owners", %{server: server} do
    for i <- 1..256 do
      {:ok, lease} = Limiter.acquire("principal-#{i}", server)
      Limiter.release(lease, server)
    end

    assert {:error, :rate_limited} = Limiter.acquire("principal-overflow", server)
    assert map_size(:sys.get_state(server).windows) == 256

    for principal <- [nil, "", String.duplicate("x", 513)] do
      assert {:error, :unavailable} = Limiter.acquire(principal, server)
    end

    assert Process.alive?(server)
  end

  defp assert_released(server, lease, attempts) do
    if Map.has_key?(:sys.get_state(server).leases, lease) and attempts > 0 do
      Process.sleep(10)
      assert_released(server, lease, attempts - 1)
    else
      refute Map.has_key?(:sys.get_state(server).leases, lease)
    end
  end
end
