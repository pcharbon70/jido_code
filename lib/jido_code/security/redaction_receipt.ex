defmodule JidoCode.Security.RedactionReceipt do
  @moduledoc """
  Bounded transient evidence that an output was classified and sanitized.

  Durable redaction evidence must be recorded through a semantic command; this
  struct itself is never persisted as product truth.
  """

  @enforce_keys [:classification_version, :redacted_count, :checked_count, :outcome]
  defstruct @enforce_keys
end
