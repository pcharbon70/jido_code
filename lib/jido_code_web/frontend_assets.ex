defmodule JidoCodeWeb.FrontendAssets do
  @moduledoc false

  @manifest_path "priv/static/.vite/manifest.json"
  @ssr_manifest_path "priv/static/.vite/ssr-manifest.json"
  @ssr_bundle_path "priv/static/server.mjs"
  @asset_names ["js/app.js", "css/app.css"]

  @test_manifest PhoenixVite.Manifest.parse(%{
                   "js/app.js" => %{
                     "file" => "assets/test.js",
                     "css" => ["assets/test.css"],
                     "imports" => []
                   },
                   "css/app.css" => %{
                     "file" => "assets/test.css",
                     "css" => [],
                     "imports" => []
                   }
                 })

  @fallback_manifest PhoenixVite.Manifest.parse(%{
                       "js/app.js" => %{
                         "file" => "assets/app.js",
                         "css" => ["assets/app.css"],
                         "imports" => []
                       },
                       "css/app.css" => %{
                         "file" => "assets/app.css",
                         "css" => [],
                         "imports" => []
                       }
                     })

  @spec asset_names() :: [String.t()]
  def asset_names, do: @asset_names

  @spec client_manifest_path() :: String.t()
  def client_manifest_path, do: @manifest_path

  @spec ssr_manifest_path() :: String.t()
  def ssr_manifest_path, do: @ssr_manifest_path

  @spec ssr_bundle_path() :: String.t()
  def ssr_bundle_path, do: @ssr_bundle_path

  @spec vite_manifest() :: PhoenixVite.Manifest.t() | {atom(), String.t()}
  def vite_manifest do
    case status() do
      %{manifest: manifest} -> manifest
      %{manifest_path: manifest_path} -> {:jido_code, manifest_path}
    end
  end

  @spec status() :: map()
  def status do
    runtime_mode = Application.get_env(:jido_code, :runtime_mode, :prod)
    dev_server? = PhoenixVite.Components.has_vite_watcher?(JidoCodeWeb.Endpoint)

    cond do
      runtime_mode == :test ->
        %{mode: :ready, manifest: @test_manifest}

      dev_server? ->
        %{mode: :ready, manifest_path: @manifest_path}

      File.exists?(Path.join(File.cwd!(), @manifest_path)) ->
        %{mode: :ready, manifest_path: @manifest_path}

      true ->
        %{mode: :fallback, manifest: @fallback_manifest}
    end
  end
end
