defmodule JidoCode.Knowledge.Reasoning.Profiles do
  @moduledoc "Reviewed bounded profiles over TripleStore's OWL 2 RL rule engine."

  alias JidoCode.Knowledge.Error
  alias TripleStore.Reasoner.ReasoningProfile

  @profiles %{
    class_hierarchy: [:scm_sco, :cax_sco],
    capability_hierarchy: [:scm_sco, :cax_sco],
    repository_cohort: [:scm_sco, :cax_sco, :prp_dom, :prp_rng],
    dependency_transitivity: [:prp_trp],
    knowledge_applicability: [:scm_sco, :cax_sco, :prp_dom, :prp_rng],
    owl2rl_safe: [
      :scm_sco,
      :scm_spo,
      :cax_sco,
      :prp_spo1,
      :prp_dom,
      :prp_rng,
      :prp_trp,
      :prp_symp,
      :prp_inv1,
      :prp_inv2,
      :cls_hv1,
      :cls_hv2,
      :cls_svf1,
      :cls_svf2,
      :cls_avf
    ]
  }

  @spec names() :: [atom()]
  def names, do: @profiles |> Map.keys() |> Enum.sort()

  @spec rules(atom()) :: {:ok, list()} | {:error, Error.t()}
  def rules(profile) do
    case Map.fetch(@profiles, profile) do
      {:ok, names} ->
        case ReasoningProfile.rules_for(:custom, rules: names) do
          {:ok, rules} -> {:ok, rules}
          {:error, _reason} -> invalid()
        end

      :error ->
        invalid()
    end
  rescue
    _error -> invalid()
  end

  @spec rule_names(atom()) :: {:ok, [atom()]} | {:error, Error.t()}
  def rule_names(profile) do
    case Map.fetch(@profiles, profile) do
      {:ok, names} -> {:ok, names}
      :error -> invalid()
    end
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :reasoning_profile)}
end
