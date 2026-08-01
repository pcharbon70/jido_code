defmodule JidoCode.Knowledge.ProjectionDefinition do
  @moduledoc false

  @enforce_keys [
    :name,
    :version,
    :query_name,
    :query_version,
    :shape,
    :purpose,
    :decoder,
    :compatibility_notes
  ]
  defstruct @enforce_keys

  @type shape :: :scalar | :table | :timeline | :tree | :bounded_subgraph
  @type t :: %__MODULE__{}
end
