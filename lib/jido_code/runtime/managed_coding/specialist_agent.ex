defmodule JidoCode.Runtime.ManagedCoding.SpecialistAgent do
  @moduledoc "Disposable process projection for one graph-authorized specialist delegation."

  use Jido.Agent,
    name: "managed_coding_specialist",
    description: "Bounded specialist with no direct durable or acceptance authority",
    schema: [
      topology_iri: [type: :string, required: true],
      delegation_iri: [type: :string, required: true],
      task_iri: [type: :string, required: true],
      attempt_iri: [type: :string, required: true],
      role: [type: :string, required: true],
      fencing_token: [type: :pos_integer, required: true],
      reconstruction_watermark: [type: :string, required: true],
      sequence: [type: :non_neg_integer, default: 0]
    ]
end
