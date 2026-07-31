defmodule ArchitectureFixture.EntityStore do
  @derive Jason.Encoder
  defstruct [:repository_id, :owner_id]

  def encode_record(record), do: Jason.encode!(record)
end
