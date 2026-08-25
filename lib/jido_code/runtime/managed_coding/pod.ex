defmodule JidoCode.Runtime.ManagedCoding.Pod do
  @moduledoc "Fixed Jido.Pod projection for the evaluated managed coding roles."

  alias JidoCode.Runtime.ManagedCoding.SpecialistAgent

  use Jido.Pod,
    name: "managed_coding_pod",
    description: "Evaluation-only projection of a graph-owned specialist topology",
    schema: [
      topology_iri: [type: :string, required: true],
      profile_digest: [type: :string, required: true],
      reconstruction_watermark: [type: :string, required: true]
    ],
    topology: %{
      "investigator" => %{
        module: SpecialistAgent,
        manager: JidoCode.Runtime.ManagedCoding.SpecialistManager,
        activation: :lazy
      },
      "coder" => %{
        module: SpecialistAgent,
        manager: JidoCode.Runtime.ManagedCoding.SpecialistManager,
        activation: :lazy
      },
      "reviewer" => %{
        module: SpecialistAgent,
        manager: JidoCode.Runtime.ManagedCoding.SpecialistManager,
        activation: :lazy
      }
    }
end
