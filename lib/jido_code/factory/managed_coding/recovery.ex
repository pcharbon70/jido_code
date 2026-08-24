defmodule JidoCode.Factory.ManagedCoding.Recovery do
  @moduledoc "Graph-only restart classification for disposable managed coding runtimes."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Vocabulary

  @non_effecting %{
    admitted: :restart_from_admission,
    preparing: :rebuild_context,
    assembling_candidate: :rebuild_candidate,
    candidate_ready: :handoff_candidate
  }
  @effecting ~w[awaiting_model awaiting_tool cancelling]a
  @terminal ~w[completed cancelled failed]a
  @digest ~r/^[a-f0-9]{64}$/

  @spec classify(map(), map()) :: {:ok, atom() | tuple()} | {:error, AdapterError.t()}
  def classify(projection, baseline) when is_map(projection) and is_map(baseline) do
    phase = projection[:phase]

    with true <- Vocabulary.valid?(:runtime_phase, phase),
         true <- valid_digest?(projection[:strategy_revision]),
         true <- valid_digest?(projection[:reconstruction_watermark]),
         true <- is_binary(projection[:profile_iri]),
         true <- is_binary(projection[:attempt_iri]) do
      cond do
        projection.profile_iri != baseline[:profile_iri] ->
          {:ok, {:supersede, :incompatible_profile}}

        projection.strategy_revision != baseline[:strategy_revision] ->
          {:ok, {:supersede, :incompatible_strategy}}

        phase in @terminal ->
          {:ok, :ignore_terminal}

        Map.has_key?(@non_effecting, phase) ->
          {:ok, Map.fetch!(@non_effecting, phase)}

        phase in @effecting ->
          {:ok, {:reconcile_effect, phase}}

        true ->
          {:error, AdapterError.new(:corrupt, :managed_coding_recovery)}
      end
    else
      _invalid -> {:error, AdapterError.new(:corrupt, :managed_coding_recovery)}
    end
  rescue
    _error -> {:error, AdapterError.new(:corrupt, :managed_coding_recovery)}
  end

  def classify(_projection, _baseline),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_recovery)}

  defp valid_digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
end
