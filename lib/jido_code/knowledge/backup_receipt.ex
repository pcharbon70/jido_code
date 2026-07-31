defmodule JidoCode.Knowledge.BackupReceipt do
  @moduledoc """
  Bounded result returned after creating a backup or RDF export artifact.
  """

  @enforce_keys [
    :artifact_id,
    :artifact_kind,
    :created_at,
    :dataset_revision,
    :graph_count,
    :quad_count,
    :payload_sha256,
    :payload_bytes,
    :consistency
  ]
  defstruct [
    :artifact_id,
    :artifact_kind,
    :created_at,
    :dataset_revision,
    :graph_count,
    :quad_count,
    :payload_sha256,
    :payload_bytes,
    :consistency
  ]

  @type t :: %__MODULE__{
          artifact_id: String.t(),
          artifact_kind: :checkpoint | :nquads | :trig,
          created_at: String.t(),
          dataset_revision: non_neg_integer(),
          graph_count: non_neg_integer(),
          quad_count: non_neg_integer(),
          payload_sha256: String.t(),
          payload_bytes: non_neg_integer(),
          consistency: String.t()
        }
end
