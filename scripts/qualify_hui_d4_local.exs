# Run after MIX_ENV=prod mix assets.deploy, with PHX_SERVER=false.
# Only disposable qualification data is written; credentials are never emitted.
true = Mix.env() == :prod
false = Application.get_env(:jido_code, :hypermedia_qualification_build)
root = Path.join(System.tmp_dir!(), "hui-d4-local-#{System.unique_integer([:positive])}")
File.mkdir_p!(root)
File.chmod!(root, 0o700)
{:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
{:ok, port} = :inet.port(socket)
:ok = :gen_tcp.close(socket)
{:ok, transport} = JidoCode.LocalDeployment.transport(%{"PORT" => Integer.to_string(port)})
credential = Base.url_encode64(:crypto.strong_rand_bytes(32))
token = Base.url_encode64(:crypto.strong_rand_bytes(32))

Application.put_env(:jido_code, :authority_bootstrap, %{
  enabled?: true, token_digest: :crypto.hash(:sha256, token)
})
Application.put_env(:jido_code, :knowledge_store,
  enabled: true, root: Path.join(root, "graph"), backup_root: Path.join(root, "backups"))
Application.put_env(:jido_code, :human_identity,
  Application.fetch_env!(:jido_code, :human_identity)
  |> Keyword.merge(enabled: true, persistence: true, path: Path.join(root, "identity"),
    integrity_key: :crypto.strong_rand_bytes(32), bootstrap: nil,
    authority_adapter: JidoCode.Identity.Authority.LocalGraph))
Application.put_env(:jido_code, JidoCodeWeb.Endpoint,
  Application.fetch_env!(:jido_code, JidoCodeWeb.Endpoint)
  |> Keyword.merge(transport)
  |> Keyword.merge(server: true, secret_key_base: Base.encode64(:crypto.strong_rand_bytes(64))))
{:ok, _} = Application.ensure_all_started(:jido_code)
{:ok, _} = JidoCode.LocalInstall.bootstrap(
  %{login: "local-proof@example.test", display_name: "Local qualification human"}, credential, token)
%{ready?: true} = JidoCode.LocalDeployment.readiness()
base = "http://127.0.0.1:#{port}"

for headers <- [[{"host", "attacker.example"}], [{"forwarded", "for=127.0.0.1"}],
                [{"x-forwarded-proto", "https"}]] do
  %{status: 421} = Req.get!(base <> "/sign-in", headers: headers, retry: false)
end

{output, result} = System.cmd("node", ["scripts/qualify_hui_d4_local.mjs"],
  env: [{"HUI_D4_BASE", base}, {"HUI_D4_LOGIN", "local-proof@example.test"},
        {"HUI_D4_CREDENTIAL", credential}], stderr_to_stdout: true)
IO.write(output)
true = Enum.any?(:telemetry.list_handlers([:phoenix, :router_dispatch, :start]),
  &(&1.id == {Phoenix.Logger, [:phoenix, :router_dispatch, :start]}))
:ok = JidoCode.LocalDeployment.drain()
Process.sleep(500)
%{connections: 0} = JidoCode.Product.StreamCoordinator.stats()
revision = JidoCode.Knowledge.StoreServer.summary().dataset_revision
:ok = Application.stop(:jido_code)
{:ok, _} = Application.ensure_all_started(:jido_code)
true = Enum.any?(1..150, fn _ ->
  if JidoCode.LocalDeployment.readiness().ready?, do: true, else: (Process.sleep(100); false)
end)
^revision = JidoCode.Knowledge.StoreServer.summary().dataset_revision
{restarted_output, restarted_result} = System.cmd("node", ["scripts/qualify_hui_d4_local.mjs"],
  env: [{"HUI_D4_BASE", base}, {"HUI_D4_LOGIN", "local-proof@example.test"},
        {"HUI_D4_CREDENTIAL", credential}], stderr_to_stdout: true)
IO.write(restarted_output)
:ok = Application.stop(:jido_code)
IO.puts("Local production qualification exit=#{result}; disposable evidence data: #{root}")
if result != 0 or restarted_result != 0, do: System.halt(1)
