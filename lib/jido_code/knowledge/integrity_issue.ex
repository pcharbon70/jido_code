defmodule JidoCode.Knowledge.IntegrityIssue do
  @moduledoc """
  Stable, bounded diagnostic emitted by a read-only integrity inspection.
  """

  @enforce_keys [:code, :severity, :remediation]
  defstruct [:code, :severity, :reference, :remediation]

  @type severity :: :error | :warning
  @type t :: %__MODULE__{
          code: atom(),
          severity: severity(),
          reference: String.t() | nil,
          remediation: atom()
        }
end
