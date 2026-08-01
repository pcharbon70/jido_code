defmodule JidoCode.Knowledge.QueryDefinition do
  @moduledoc """
  Reviewed contract for one immutable catalog query version.

  Definitions are executable code metadata. Persisted graph revisions and the
  returned query receipt remain the authority for every evaluated answer.
  """

  @enforce_keys [
    :name,
    :version,
    :purpose,
    :form,
    :parameters,
    :capability,
    :graph_families,
    :completeness,
    :limits,
    :decoder,
    :source,
    :source_digest,
    :execution_class,
    :compatibility_notes
  ]
  defstruct @enforce_keys ++ [allow_graph_variable?: false]

  @type form :: :select | :ask | :construct
  @type t :: %__MODULE__{}

  @spec source_digest(String.t()) :: String.t()
  def source_digest(source) when is_binary(source) do
    :crypto.hash(:sha256, source) |> Base.encode16(case: :lower)
  end
end
