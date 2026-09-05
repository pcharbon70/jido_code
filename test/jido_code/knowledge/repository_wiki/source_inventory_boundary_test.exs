defmodule JidoCode.Knowledge.RepositoryWiki.SourceInventoryBoundaryTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.RepositoryWiki.SourceInventoryHelperBoundary
  alias JidoCode.Knowledge.RepositoryWiki.SourceInventoryProtocol

  test "directory protocol requires exact bounded frames, terminal count, EOF, and success" do
    body = directory_body(["alpha.md", "beta.ex"])

    assert {:ok, ["alpha.md", "beta.ex"]} =
             SourceInventoryProtocol.decode_directory(body, 0, true, 2)

    assert {:error, :directory_protocol} =
             SourceInventoryProtocol.decode_directory(body, 0, false, 2)

    assert {:error, :directory_protocol} =
             SourceInventoryProtocol.decode_directory(
               binary_part(body, 0, byte_size(body) - 1),
               0,
               true,
               2
             )

    assert {:error, :directory_protocol} =
             SourceInventoryProtocol.decode_directory(body <> <<0>>, 0, true, 2)

    wrong_count = frame("alpha.md") <> terminal(2)

    assert {:error, :directory_protocol} =
             SourceInventoryProtocol.decode_directory(wrong_count, 0, true, 2)

    assert {:error, :directory_enumeration_limit} =
             SourceInventoryProtocol.decode_directory(body, 0, true, 1)

    assert {:error, :directory_protocol} =
             SourceInventoryProtocol.decode_directory(
               <<513::unsigned-big-16, 0::size(513 * 8)>>,
               0,
               true,
               2
             )

    for unsafe <- ["unsafe\nname", <<0xFF>>, ".", "..", "path/name"] do
      assert {:error, :directory_name_encoding} =
               SourceInventoryProtocol.decode_directory(frame(unsafe) <> terminal(1), 0, true, 2)
    end

    assert {:error, :directory_enumeration_limit} =
             SourceInventoryProtocol.decode_directory(<<0, 5, 0>>, 75, true, 2)
  end

  test "directory status policy distinguishes path, timeout, resource, and runtime failures" do
    expectations = %{
      76 => :directory_name_encoding,
      77 => :directory_enumerator_unavailable,
      78 => :directory_enumeration_timeout,
      79 => :directory_unreadable,
      80 => :directory_changed_during_read,
      86 => :directory_enumeration_resource_limit,
      124 => :directory_enumeration_timeout,
      137 => :directory_enumeration_timeout,
      152 => :directory_enumeration_resource_limit,
      255 => :directory_enumerator_unavailable
    }

    for {status, reason} <- expectations do
      assert {:error, ^reason} =
               SourceInventoryProtocol.decode_directory(<<1, 2, 3>>, status, true, 4)
    end
  end

  test "file protocol rejects partial, trailing, oversized, and unsuccessful output" do
    contents = <<0, 1, 2, 255, ?a, ?b>>
    body = file_body(contents)

    assert {:ok, ^contents} = SourceInventoryProtocol.decode_file(body, 0, true, 32)
    assert {:error, :path_protocol} = SourceInventoryProtocol.decode_file(body, 0, false, 32)

    for invalid <- [
          binary_part(body, 0, byte_size(body) - 1),
          body <> <<0>>,
          <<"BAD1", 0::unsigned-big-32, "JCE1">>,
          <<"JCF1", 33::unsigned-big-32, 0::size(33 * 8), "JCE1">>,
          <<"JCF1", 7::unsigned-big-32, contents::binary, "JCE1">>
        ] do
      assert {:error, :path_protocol} = SourceInventoryProtocol.decode_file(invalid, 0, true, 32)
    end

    assert {:error, :path_changed_during_read} =
             SourceInventoryProtocol.decode_file(binary_part(body, 0, 5), 80, true, 32)
  end

  test "file status policy covers the complete fixed helper exit vocabulary" do
    expectations = %{
      75 => {:error, :path_helper_unavailable},
      76 => {:error, :path_protocol},
      77 => {:error, :path_helper_unavailable},
      78 => {:error, :path_timeout},
      79 => {:error, :path_unreadable},
      80 => {:error, :path_changed_during_read},
      81 => {:error, :path_oversized},
      82 => {:type, :unsupported},
      83 => {:type, :directory},
      84 => {:type, :symlink},
      85 => {:error, :path_missing},
      86 => {:error, :path_resource_limit},
      124 => {:error, :path_timeout},
      137 => {:error, :path_timeout},
      152 => {:error, :path_resource_limit},
      255 => {:error, :path_helper_unavailable}
    }

    for {status, expected} <- expectations do
      assert ^expected = SourceInventoryProtocol.decode_file(<<1, 2, 3>>, status, true, 32)
    end
  end

  test "the four-slot coordinator retains a permit across caller cancellation" do
    parent = self()
    options = boundary_options(4, 1_500, 100)
    deadline = deadline(10_000)

    callers =
      for id <- 1..4 do
        spawn(fn ->
          result =
            SourceInventoryHelperBoundary.run(
              fn ->
                send(parent, {:started, id, self()})
                receive do: (:finish -> id)
              end,
              deadline,
              :worker_limit,
              :worker_timeout,
              options
            )

          send(parent, {:result, id, result})
        end)
      end

    started = collect_started(4, %{})
    Process.exit(hd(callers), :kill)

    fifth =
      spawn(fn ->
        result =
          SourceInventoryHelperBoundary.run(
            fn ->
              send(parent, {:started, :fifth, self()})
              receive do: (:finish -> :fifth)
            end,
            deadline,
            :worker_limit,
            :worker_timeout,
            options
          )

        send(parent, {:result, :fifth, result})
      end)

    refute_receive {:started, :fifth, _worker}, 150
    send(Map.fetch!(started, 1), :finish)
    assert_receive {:started, :fifth, fifth_worker}, 1_000

    Enum.each(Map.delete(started, 1), fn {_id, worker} -> send(worker, :finish) end)
    send(fifth_worker, :finish)

    for id <- [2, 3, 4, :fifth], do: assert_receive({:result, ^id, ^id}, 1_000)
    Process.exit(fifth, :kill)
  end

  test "an abnormally dead worker retains its only permit for a fresh cleanup window" do
    parent = self()
    options = boundary_options(1, 200, 50)
    deadline = deadline(2_000)

    spawn(fn ->
      result =
        SourceInventoryHelperBoundary.run(
          fn ->
            send(parent, :dying_worker_started)
            Process.exit(self(), :kill)
          end,
          deadline,
          :worker_limit,
          :worker_timeout,
          options
        )

      send(parent, {:dying_result, result})
    end)

    assert_receive :dying_worker_started, 500

    spawn(fn ->
      result =
        SourceInventoryHelperBoundary.run(
          fn ->
            send(parent, :successor_started)
            :ok
          end,
          deadline,
          :worker_limit,
          :worker_timeout,
          options
        )

      send(parent, {:successor_result, result})
    end)

    refute_receive :successor_started, 100
    assert_receive {:dying_result, {:error, :worker_limit}}, 500
    assert_receive :successor_started, 500
    assert_receive {:successor_result, :ok}, 500
  end

  defp directory_body(names), do: Enum.map_join(names, &frame/1) <> terminal(length(names))
  defp frame(name), do: <<byte_size(name)::unsigned-big-16, name::binary>>
  defp terminal(count), do: <<5::unsigned-big-16, 0, count::unsigned-big-32>>

  defp file_body(contents),
    do: <<"JCF1", byte_size(contents)::unsigned-big-32, contents::binary, "JCE1">>

  defp boundary_options(concurrency, receiver_timeout_ms, helper_wall_ms) do
    %{
      slot_scope: {__MODULE__, make_ref()},
      concurrency: concurrency,
      receiver_timeout_ms: receiver_timeout_ms,
      helper_wall_ms: helper_wall_ms,
      heap_words: 100_000
    }
  end

  defp deadline(milliseconds), do: System.monotonic_time(:millisecond) + milliseconds

  defp collect_started(0, started), do: started

  defp collect_started(remaining, started) do
    assert_receive {:started, id, worker}, 1_000
    collect_started(remaining - 1, Map.put(started, id, worker))
  end
end
