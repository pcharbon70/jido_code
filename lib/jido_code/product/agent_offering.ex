defmodule JidoCode.Product.AgentOffering do
  @moduledoc "Disposable, scope-filtered presentation of one coding agent profile."

  @enforce_keys [
    :reference,
    :display_name,
    :description,
    :runtime_class,
    :provider,
    :deployment_class,
    :authentication_kind,
    :billing_mode,
    :capability_class,
    :capability_summary,
    :task_classes,
    :language_classes,
    :readiness,
    :readiness_age_seconds,
    :rollout_stage,
    :profile_revision,
    :profile_digest,
    :limitations,
    :selectable
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec safe_map(t()) :: map()
  def safe_map(%__MODULE__{} = offering), do: Map.from_struct(offering)
end
