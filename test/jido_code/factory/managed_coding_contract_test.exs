defmodule JidoCode.Factory.ManagedCodingContractTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.ManagedCoding
  alias JidoCode.Factory.ManagedCoding.Command
  alias JidoCode.Factory.ManagedCoding.Outcome
  alias JidoCode.Factory.ManagedCoding.RuntimeIdentity
  alias JidoCode.TestSupport.FakeManagedCoding

  test "accepts bounded semantic commands through the matching facade operation" do
    command = command!(:admit)

    assert {:ok, outcome} =
             ManagedCoding.admit(FakeManagedCoding, command,
               attempt_iri: iri("attempt"),
               fencing_token: 1
             )

    assert outcome.state == :admitted
    assert outcome.attempt_iri == iri("attempt")
    assert {:error, %{kind: :invalid_input}} = ManagedCoding.start(FakeManagedCoding, command)
  end

  test "requires attempt and fence after admission and rejects runtime implementation state" do
    assert {:error, _error} = Command.new(attributes(:start))

    assert {:ok, _command} =
             attributes(:start)
             |> Map.merge(%{attempt_iri: iri("attempt"), fencing_token: 2})
             |> Command.new()

    assert {:error, _error} =
             attributes(:admit)
             |> Map.put(:payload, %{pid: self()})
             |> Command.new()

    assert {:error, _error} =
             attributes(:admit)
             |> Map.put(:payload, %{workspace_path: "/tmp/work"})
             |> Command.new()
  end

  test "compares runtime identity by attempt and fence" do
    assert {:ok, current} = RuntimeIdentity.new(iri("attempt"), 2)
    assert {:ok, same} = RuntimeIdentity.new(iri("attempt"), 2)
    assert {:ok, stale} = RuntimeIdentity.new(iri("attempt"), 1)
    assert {:ok, next} = RuntimeIdentity.new(iri("attempt"), 3)
    assert {:ok, other} = RuntimeIdentity.new(iri("other"), 2)

    assert RuntimeIdentity.compare(same, current) == :current
    assert RuntimeIdentity.compare(stale, current) == :stale
    assert RuntimeIdentity.compare(next, current) == :superseding
    assert RuntimeIdentity.compare(other, current) == :different_attempt
  end

  test "outcomes reject invalid fences and non-semantic references" do
    base = %{
      attempt_iri: iri("attempt"),
      fencing_token: 1,
      state: :running,
      sequence: 1,
      occurred_at: ~U[2026-08-24 14:00:00Z],
      references: [iri("event")]
    }

    assert {:ok, _outcome} = Outcome.new(base)
    assert {:error, _error} = Outcome.new(%{base | fencing_token: 0})
    assert {:error, _error} = Outcome.new(%{base | references: ["relative"]})
  end

  defp command!(operation) do
    {:ok, command} = Command.new(attributes(operation))
    command
  end

  defp attributes(operation) do
    %{
      operation: operation,
      command_iri: iri("command-#{operation}"),
      repository_iri: iri("repository"),
      task_iri: iri("task"),
      actor_iri: iri("actor"),
      profile_iri: iri("profile"),
      capability_iri: iri("capability"),
      payload: %{reason: "bounded request"}
    }
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
