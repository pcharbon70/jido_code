defmodule JidoCode.TestSupport.FakeManagedCodingCandidateStore do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ManagedCodingCandidateStore

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CandidateManifest

  @impl true
  def create(agent, manifest) do
    Agent.get_and_update(agent, fn manifests ->
      case Map.fetch(manifests, manifest.candidate_iri) do
        :error ->
          {{:ok, :committed}, Map.put(manifests, manifest.candidate_iri, manifest)}

        {:ok, existing} ->
          if CandidateManifest.material(existing) == CandidateManifest.material(manifest),
            do: {{:ok, :idempotent}, manifests},
            else: {{:error, AdapterError.new(:conflict, :candidate_store)}, manifests}
      end
    end)
  end

  @impl true
  def fetch(agent, candidate_iri) do
    case Agent.get(agent, &Map.fetch(&1, candidate_iri)) do
      {:ok, manifest} -> {:ok, manifest}
      :error -> {:error, AdapterError.new(:unavailable, :candidate_store)}
    end
  end
end
