defmodule JidoCode.Factory.Tool.ResolvedPath do
  @moduledoc "Opaque, symlink-checked repository path for a filesystem adapter."

  @derive {Inspect, only: [:relative]}
  @enforce_keys [:absolute, :relative]
  defstruct @enforce_keys

  @type t :: %__MODULE__{absolute: Path.t(), relative: Path.t()}
end
