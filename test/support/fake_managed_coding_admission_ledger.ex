defmodule JidoCode.TestSupport.FakeManagedCodingAdmissionLedger do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ManagedCodingAdmissionLedger

  alias JidoCode.Factory.AdapterError

  @impl true
  def resolve(agent, command) do
    state = Agent.get(agent, & &1)
    send(state.owner, {:ledger, :resolve, command.command_iri})
    Map.get(state, :resolve_result, {:ok, state.resolved})
  end

  @impl true
  def commit(agent, command, resolved) do
    state = Agent.get(agent, & &1)
    send(state.owner, {:ledger, :commit, command.command_iri})

    case Map.get(state, :commit_result, :commit) do
      :commit ->
        Agent.update(agent, fn current ->
          put_in(current, [:admissions, resolved.attempt_iri], %{resolved: resolved})
        end)

        {:ok, %{outcome: :committed}}

      :idempotent ->
        {:ok, %{outcome: :idempotent}}

      {:error, kind} ->
        {:error, AdapterError.new(kind, :managed_coding_admission_commit)}
    end
  end

  @impl true
  def fetch(agent, attempt_iri, fencing_token) do
    state = Agent.get(agent, & &1)
    send(state.owner, {:ledger, :fetch, attempt_iri, fencing_token})

    case get_in(state, [:admissions, attempt_iri]) do
      %{resolved: %{fencing_token: ^fencing_token}} = admission -> {:ok, admission}
      _missing -> {:error, AdapterError.new(:unauthorized, :managed_coding_admission_fetch)}
    end
  end

  @impl true
  def runtime_started(agent, admission, receipt) do
    state = Agent.get(agent, & &1)
    send(state.owner, {:ledger, :runtime_started, admission.resolved.attempt_iri, receipt})
    :ok
  end

  @impl true
  def start_failed(agent, admission, error) do
    state = Agent.get(agent, & &1)
    send(state.owner, {:ledger, :start_failed, admission.resolved.attempt_iri, error.kind})
    :ok
  end
end
