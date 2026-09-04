defmodule Mix.Tasks.Assets.NormalizeDigestManifest do
  use Mix.Task

  @shortdoc "Normalizes generated asset-manifest timestamps for reproducible builds"
  @manifest "priv/static/cache_manifest.json"
  @fixed_mtime 63_955_699_200

  @impl Mix.Task
  def run(_arguments) do
    body = File.read!(@manifest)

    pattern = ~r/"mtime":\d+/
    count = pattern |> Regex.scan(body) |> length()
    normalized = Regex.replace(pattern, body, ~s("mtime":#{@fixed_mtime}))

    if count == 0 do
      Mix.raise("#{@manifest} contains no digest mtimes to normalize")
    end

    File.write!(@manifest, normalized)
    Mix.Project.build_structure()
    Mix.shell().info("Normalized #{count} digest manifest timestamp(s)")
  end
end
