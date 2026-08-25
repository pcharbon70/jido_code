defmodule JidoCode.TestSupport.ManagedCodingCompatibilityPod do
  @moduledoc false

  use Jido.Pod,
    name: "managed_coding_compatibility_pod",
    topology: %{
      "worker" => %{
        module: JidoCode.Runtime.ExecutionAgent,
        manager: :managed_coding_compatibility_specialists,
        activation: :eager,
        initial_state: %{
          attempt_iri: "https://jido.run/id/attempt/pod-compatibility",
          fencing_token: 1
        }
      }
    }
end
