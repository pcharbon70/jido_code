defmodule JidoCode.Knowledge.ApplicationLifecycleTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  test "supervises independent readiness while the test store is disabled" do
    assert Process.alive?(Process.whereis(JidoCode.Knowledge.Supervisor))
    assert Process.alive?(Process.whereis(JidoCode.Knowledge.Readiness))
    assert Process.alive?(Process.whereis(JidoCode.Knowledge.StoreServer))
    assert Process.alive?(Process.whereis(JidoCode.Knowledge.QueryRunner))
    assert Process.alive?(Process.whereis(JidoCode.Knowledge.Writer))
    assert Process.alive?(Process.whereis(JidoCode.Knowledge.Maintenance))
    assert Process.alive?(Process.whereis(JidoCodeWeb.Endpoint))

    refute Knowledge.ready?()
    assert Knowledge.health().state == :unavailable
    assert Knowledge.store_summary().store_open? == false
    assert {:error, %Error{kind: :unavailable}} = Knowledge.gate(:durable_command)
  end
end
