defmodule Mix.Tasks.JidoCode.Capacity do
  @moduledoc "Runs the bounded synthetic release-capacity operation matrix."

  use Mix.Task

  alias JidoCode.Capacity
  alias JidoCode.Capacity.Benchmark

  @shortdoc "Run bounded fleet capacity benchmarks"

  @impl true
  def run(arguments) do
    Mix.Task.run("app.start")
    profile = parse_profile(arguments)
    {:ok, workload} = Capacity.profile(profile)
    {:ok, admission} = Capacity.admit(workload)
    callbacks = Map.new(Benchmark.operations(), &{&1, synthetic_callback(&1, workload)})

    case Benchmark.run(callbacks, iterations: 3, timeout: 5_000) do
      {:ok, results} ->
        Mix.shell().info("profile=#{profile} pressure=#{admission.pressure}")

        Enum.each(Benchmark.operations(), fn operation ->
          result = results[operation]
          Mix.shell().info("#{operation} p50_us=#{result.p50_us} p95_us=#{result.p95_us}")
        end)

      {:error, error} ->
        Mix.raise("capacity benchmark failed: #{error.operation}")
    end
  end

  defp parse_profile(["--profile", "small"]), do: :small
  defp parse_profile(["--profile", "medium"]), do: :medium
  defp parse_profile(["--profile", "maximum"]), do: :maximum

  defp parse_profile([]), do: :small

  defp parse_profile(_arguments),
    do: Mix.raise("usage: mix jido_code.capacity [--profile PROFILE]")

  defp synthetic_callback(operation, workload) do
    sample_size = min(div(workload.observations, 1_000) + workload.repositories, 10_000)

    fn ->
      1..max(sample_size, 1)
      |> Enum.map(&:erlang.phash2({operation, &1}))
      |> Enum.sort()
      |> Enum.take(100)
    end
  end
end
