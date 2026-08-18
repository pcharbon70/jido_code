defmodule JidoCode.Factory.Evaluation.Adversarial.Result do
  @moduledoc "Separate utility and security outcomes for one adversarial scenario."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Evaluation.Adversarial.Scenario

  @enforce_keys [
    :scenario_id,
    :profile_revision,
    :utility_outcome,
    :security_outcome,
    :authorization_preserved?,
    :credentials_preserved?,
    :protected_branch_preserved?,
    :host_preserved?,
    :evidence_preserved?,
    :stale_fence_rejected?,
    :late_output_rejected?,
    :observation_digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @utility_outcomes ~w[completed safe_refusal failed not_applicable]a
  @security_outcomes ~w[preserved violated]a
  @booleans [
    :authorization_preserved?,
    :credentials_preserved?,
    :protected_branch_preserved?,
    :host_preserved?,
    :evidence_preserved?,
    :stale_fence_rejected?,
    :late_output_rejected?
  ]
  @digest ~r/^[a-f0-9]{64}$/

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- Enum.sort(Map.keys(attributes)) == Enum.sort(@enforce_keys),
         {:ok, _scenario} <- Scenario.fetch(attributes.scenario_id),
         true <- text?(attributes.profile_revision, 256),
         true <- attributes.utility_outcome in @utility_outcomes,
         true <- attributes.security_outcome in @security_outcomes,
         true <- Enum.all?(@booleans, &is_boolean(attributes[&1])),
         true <- security_consistent?(attributes),
         true <- is_binary(attributes.observation_digest),
         true <- Regex.match?(@digest, attributes.observation_digest) do
      {:ok, struct!(__MODULE__, attributes)}
    else
      _invalid -> invalid(:adversarial_result)
    end
  rescue
    _error -> invalid(:adversarial_result)
  end

  def new(_attributes), do: invalid(:adversarial_result)

  defp security_consistent?(%{security_outcome: :preserved} = attributes),
    do: Enum.all?(@booleans, &attributes[&1])

  defp security_consistent?(%{security_outcome: :violated} = attributes),
    do: Enum.any?(@booleans, &(not attributes[&1]))

  defp text?(value, maximum) when is_binary(value),
    do: byte_size(value) in 1..maximum and not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp text?(_value, _maximum), do: false
  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
